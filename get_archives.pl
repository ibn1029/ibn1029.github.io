#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Data::Dumper;
use File::Which 'which';
use Test::TCP;
use Selenium::Remote::Driver;
use Web::Query 'wq';
use JSON;
use Log::Minimal;
use File::Stamped;
use Time::Piece;
use URI::Escape;
use HTML::Entities qw/decode_entities/;


my $blockfm = 'http://block.fm';
my $wait = 1;

#
# Config ofLog::Minimal
#
BEGIN {
    my $fh = File::Stamped->new(
        pattern => 'logs/%Y%m%d.log',
    );
    $Log::Minimal::PRINT = sub {
        my ($time, $type, $message, $trace, $raw_message) = @_;
        #$fh->print("$time [$type] $message at $trace\n");
        print "$time [$type] $message\n";
        $fh->print("$time [$type] $message\n");
    };
}

#
# Setup phantonjs and selenium 
#
my $bin = scalar which 'phantomjs';
my $phantomjs = Test::TCP->new(
    code => sub {
        my $port = shift; # assign undefined local port
        exec $bin, '--webdriver', $port;
        die "cannot execute $bin: $!";
    }
);
my $ua = Selenium::Remote::Driver->new(
    remote_server_addr => '127.0.0.1',
    port => $phantomjs->port,
);
$ua->debug_off;

#
# Process of BlockFM
#
my @archives;
infof("$blockfm/?cat=program");
$ua->get("$blockfm/?cat=program"); sleep $wait;
my $program_urls = scrape_programs($ua->get_page_source);
for my $program_url (@$program_urls) {

    infof($blockfm.$program_url);
    $ua->get($blockfm.$program_url); sleep $wait;
    my $archive_url = scrape_archive($ua->get_page_source);
    unless ($archive_url) {
        infof('ARCHIVE URL NOT FOUND!!!');
        next;
    }

    infof($blockfm.$archive_url);
    $ua->get($blockfm.$archive_url); sleep $wait;
    my $id = scrape_id($ua->get_page_source);
    unless ($id) {
        infof('ID NOT FOUND!!!');
        next;
    }

    infof("http://api.block.fm/app/program/?_id=$id");
    $ua->get("http://api.block.fm/app/program/?_id=$id"); sleep 1;
    push @archives, get_data($ua->get_page_source);
}

#
# Process of SoundCloud
#
my @sc_archives;
my @sorted_archives = sort { $b->{start_date} <=> $a->{start_date} } @archives;
for my $archive (@sorted_archives) {
    next unless $archive->{soundcloud};
    infof($archive->{soundcloud});
    if (my $audio_url = scrape_audiofile($archive->{soundcloud})) {
        $archive->{url} = $audio_url;
        push @sc_archives, $archive;
    }
}

#
# Generate js of archives for index.html
#
undef $ua;
undef $phantomjs;
generate_archives_js(\@sc_archives);

exit;

#----------------------------------------------------------------------------
sub scrape_programs {
    my $html = shift or die 'No radio archive html.';
    my @program_urls;
    my $wq = Web::Query->new_from_html($html);
    $wq->find('section.layout.type2.radio .contents-wrap .list-items .a-wrap')->each(sub {
        my $url = $_->attr('href');
        push @program_urls, $url if $url =~ m{^/program/.+/$};
    });
    return \@program_urls;
}

sub scrape_archive {
    my $html = shift or die 'No program html.';
    my $archive_url;
    my $wq = Web::Query->new_from_html($html);
    $wq->find('h3 .a-wrap')->each(sub {
        my $url = $_->attr('href');
        unless ($archive_url) {
            $archive_url = $url if $url =~ m{^/program/.+/archive/\d+\.html$};
        }
    });
    return $archive_url;
}

sub scrape_id {
    my $html = shift or die 'No archive html.';
    $html =~ /data-pon-id="(\w+)">/;
    my $id = $1;
    return $id;
}

sub get_data {
    my $html = shift or die 'No api response html.';
    $html =~ /({.+})/;
    my $json = decode_json($1);
    my $p = $json->{program};
    my $soundcloud = $p->{soundcloud};
    $soundcloud =~ s/https/http/;
    my $data = {
        program    => $p->{program_title},
        dj         => $p->{subtitle},
        genre      => $p->{genre},
        date       => $p->{date},
        start      => $p->{start_time},
        start_date => $p->{start}{'$date'},
        end        => $p->{end_time},
        onair      => $p->{date}.'('. _get_wday() .')' . $p->{start_time} . '-' . $p->{end_time},
        soundcloud => $soundcloud,
        uuid       => $p->{uuid}{'$uuid'},
    };
    debugf(Dumper $data);
    return $data;
}

sub _get_wday {
    my $date = shift;
    my $t = Time::Piece->strptime($date, '%Y/%m/%d');
    return $t->wdayname;
}

sub scrape_audiofile {
    my $url = shift or die 'No soundcloud url.';
    my $wq = wq($url)->html();
    if ($wq =~ /window\.SC\.bufferTracks\.push\((.*)\);/) {
        my $sc_json = decode_json($1);
        my $stream_url = URI->new($sc_json->{streamUrl})->as_string;
        return decode_entities($stream_url);
    }
    return;
}

sub generate_archives_js {
    my $data = shift;
    my $json = encode_json $data;
    $json =~ s/&amp;/&/;
    open my $fh, '>', 'archives.json';
    print $fh 'var archives = '.$json;
    close $fh;
}
__END__

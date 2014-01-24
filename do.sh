#!/bin/bash
if [ `hostname` == 'dti-vps-srv85' ]; then
    HOME=/home/viage
    source $HOME/.bash_profile
    APP=$HOME/work/ibn1029.github.io
    PERLVER=5.14.4
    carton=$HOME/.plenv/versions/$PERLVER/bin/carton
    cd $APP
    $carton exec perl get_archives.pl
fi

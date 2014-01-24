#!/bin/bash
if [ `hostname` == 'dti-vps-srv85' ]; then
    cd /home/viage/work/ibn1029.github.io
else
    cd /Users/viage/Work/App/ibn1029.github.io
fi
carton exec perl get_archives.pl

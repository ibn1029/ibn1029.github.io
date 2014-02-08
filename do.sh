#!/bin/bash
#set -e
#set -x

app=get_archives.pl
app_dir=ibn1029.github.io
if [ $MODE == 'production' ]; then
    base=$HOME/work/$app_dir
else
    base=$HOME/Work/App/$app_dir
fi
carton=$HOME/.plenv/shims/carton

cd $base
$carton exec perl $app

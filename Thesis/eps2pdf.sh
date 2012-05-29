#!/bin/sh

file="$1"
newfile=`echo $file | sed -e 's/.eps/.pdf/'`

ps2pdf14 -dPDFSETTINGS=/prepress $file $newfile

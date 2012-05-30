#!/bin/sh

file="$1"
newfile=`echo $file | sed -e 's/.eps/.pdf/'`

export GS_OPTIONS="-dEmbedAllFonts=true -dPDFSETTINGS=/printer"
epstopdf $file
#ps2pdf14 -dPDFSETTINGS=/prepress $file $newfile

#!/bin/bash
set -e
set -x

## Gaston settings
#WORKDIR=/store/thumper/tmp
#WIKITRUST=/store/thumper/research/WikiTrust
#PANDUMP=/raid/thumper/pan2010dump.7z

## Redherring settings
#WORKDIR=/big/thumper/tmp
#WIKITRUST=/giant/thumper/research/WikiTrust
#PANDUMP=/giant/thumper/pan2010dump.7z

## Dev settings
WORKDIR=/data/users/thumper/research/tmp/repqual
WIKITRUST=/data/users/thumper/research/WikiTrust
ENDUMP=/data/users/thumper/research/enwiki-20100130-pages-meta-history.xml.bz2

OUTPUT=./output


(cd $WORKDIR ; rm -rf $OUTPUT)
(cd $WORKDIR ; mkdir -p $OUTPUT/cmds)
mkdir -p $WORKDIR/$OUTPUT/cmds
cp -a $WIKITRUST/analysis/*  $WORKDIR/$OUTPUT/cmds/
rm -f $WORKDIR/$OUTPUT/cmds/*.o
rm -f $WORKDIR/$OUTPUT/cmds/*.ml
rm -f $WORKDIR/$OUTPUT/cmds/*.cm*
rm -f $WORKDIR/$OUTPUT/cmds/*.annot
cp -ar ./pan2010.csv $WORKDIR/
cp -a $WIKITRUST/util/batch_process.py  $WORKDIR/$OUTPUT/cmds/


(cd $WORKDIR ; time python $OUTPUT/cmds/batch_process.py --cmd_dir $OUTPUT/cmds \
  --dir $OUTPUT --do_split --do_compute_stats --do_sort_stats \
  --do_compute_rep --do_compute_trust $ENDUMP)


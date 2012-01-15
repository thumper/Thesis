#!/bin/bash
set -e
set -x

## Gaston settings
WORKDIR=/raid/thumper/tmp-rep-enwiki
WIKITRUST=/store/thumper/research/WikiTrust
ENDUMP=/raid/dumps/enwiki-20100130-pages-meta-history.xml.bz2

## Redherring settings
#WORKDIR=/big/thumper/tmp
#WIKITRUST=/giant/thumper/research/WikiTrust
#PANDUMP=/giant/thumper/pan2010dump.7z

## Bsi-la settings
#WORKDIR=/mnt/archive3/tmp-rep
#WIKITRUST=/mnt/archive4/research/WikiTrust
#ENDUMP=/mnt/archive4/enwiki/enwiki-20100130-pages-meta-history.xml.bz2

CORES=6
OUTPUT=./output

mkdir -p $WORKDIR
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


(cd $WORKDIR ; time nice python $OUTPUT/cmds/batch_process.py --n_core $CORES \
  --cmd_dir $OUTPUT/cmds \
  --dir $OUTPUT --do_split --do_compute_stats --do_sort_stats \
  --do_compute_rep --do_compute_trust $ENDUMP)


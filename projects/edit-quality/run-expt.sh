#!/bin/bash
set -e
set -x

WORKDIR=/store/thumper/tmp
OUTPUT=./output

WIKITRUST=/store/thumper/research/WikiTrust
PANDUMP=/raid/thumper/pan2010dump.7z
MAXMEM1=400000
CORES1=3
MAXMEM2=650000
CORES2=2

function doexpt {
    echo "**************************************"
    echo "$1"
    echo
    (cd $WORKDIR ; rm -rf $OUTPUT/blobs)
    (cd $WORKDIR ; rm -rf $OUTPUT/buckets)
    (cd $WORKDIR ; rm -rf $OUTPUT/sql)
    (cd $WORKDIR ; rm -rf $OUTPUT/stats)
    (cd $WORKDIR ; rm -rf $OUTPUT/user*)
    (ulimit -v $MAXMEM1 -m $MAXMEM1 -d $MAXMEM1; cd $WORKDIR ; \
	time $OUTPUT/cmds/batch_process.py --n_core $CORES1 \
	  --cmd_dir $OUTPUT/cmds \
	  --dir $OUTPUT \
	  $2 \
	  --do_compute_stats --do_pan $PANDUMP)
    (ulimit -v $MAXMEM2 -m $MAXMEM2 -d $MAXMEM2; cd $WORKDIR ; \
	time $OUTPUT/cmds/batch_process.py --n_core $CORES2 \
	  --cmd_dir $OUTPUT/cmds \
	  --dir $OUTPUT \
	  $2 \
	  --do_sort_stats --do_pan \
	  --do_compute_rep $PANDUMP)
    (cd $WORKDIR ; $OUTPUT/cmds/extract-ratingsFrepfile.pl pan2010.csv \
	$OUTPUT/../generate_reputations.vandalrep )
    if [ ! -e "$WORKDIR/perf-editlong.txt" ]; then
	exit 1
    fi
    echo EDITLONG
    (cd $WORKDIR ; $OUTPUT/cmds/perf < perf-editlong.txt )
    echo TEXTLONG
    (cd $WORKDIR ; $OUTPUT/cmds/perf < perf-textlong.txt )
    (cd $WORKDIR ; wc perf-*.txt )
    (cd $WORKDIR ; find $OUTPUT/stats -name "*.vandalrep" -exec cat {} \; | grep triangles > triangles.tmp )
    echo "TOTAL TRIANGLES"
    awk '{ print $4 }' $WORKDIR/triangles.tmp | awk -F: '{total+=$1} END{print total}'
    echo "BAD TRIANGLES"
    awk '{ print $6 }' $WORKDIR/triangles.tmp | awk -F: '{total+=$1} END{print total}'
    rm -f $WORKDIR/perf-editlong.txt
    rm -f $WORKDIR/perf-textlong.txt
    rm -f $WORKDIR/triangles.tmp
}

# First split the wiki once
(cd $WORKDIR ; rm -rf $OUTPUT)
(cd $WORKDIR ; mkdir -p $OUTPUT/cmds)
(cp -a $WIKITRUST/analysis/*  $WORKDIR/$OUTPUT/cmds/)
(rm -f $WORKDIR/$OUTPUT/cmds/*.o)
(rm -f $WORKDIR/$OUTPUT/cmds/*.ml)
(rm -f $WORKDIR/$OUTPUT/cmds/*.cm*)
(rm -f $WORKDIR/$OUTPUT/cmds/*.annot)
(cp -a ./extract-ratingsFrepfile.pl $WORKDIR/$OUTPUT/cmds/ )
(cp -a ./perf.src/perf $WORKDIR/$OUTPUT/cmds/ )
(cp -ar ./lib $WORKDIR/ )
(cp -ar ./pan2010.csv $WORKDIR/ )
(cp -a $WIKITRUST/util/batch_process.py  $WORKDIR/$OUTPUT/cmds/)
(cd $WORKDIR ; time $OUTPUT/cmds/batch_process.py --cmd_dir $OUTPUT/cmds \
    --dir $OUTPUT --do_split $PANDUMP)

# And then do the experiments

####################################################################

# doexpt "diff=0 match-quality=0 edist=0" "--diff 0 --match_quality 0 --edit_distance 0"
# exit 0

for mq in {1..9}
do
  for ed in {1..5}
  do
    for diff in {1..8}
    do
      doexpt "diff=$diff precise match-quality=$mq edist=$ed" "--diff $diff --precise --match_quality $mq --edit_distance $ed"
    done
  done
done
exit 0;

####################################################################

for diff in {1..8}
do
  doexpt "diff=$diff match-quality=1 edist=5" "--diff $diff --match_quality 1 --edit_distance 5"
  doexpt "diff=$diff match-quality=8 edist=5" "--diff $diff --match_quality 8 --edit_distance 5"
done

####################################################################


#!/bin/bash
set -e
set -x


WIKITRUST=/store/thumper/research/WikiTrust
PANDUMP=/raid/thumper/pan2010dump.7z
MAXMEM=400000
CORES=3

function doexpt {
    echo "**************************************"
    echo "$1"
    echo
    (cd $WIKITRUST/util ; rm -rf output/blobs)
    (cd $WIKITRUST/util ; rm -rf output/buckets)
    (cd $WIKITRUST/util ; rm -rf output/sql)
    (cd $WIKITRUST/util ; rm -rf output/stats)
    (cd $WIKITRUST/util ; rm -rf output/user*)
    (ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WIKITRUST/util ; time ./batch_process.py --n_core $CORES --cmd_dir ../analysis \
	  --dir output \
	  $2 \
          --do_compute_stats $PANDUMP)
    (ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WIKITRUST/util ; \
	time ./batch_process.py --n_core $CORES --cmd_dir ../analysis \
	  --dir output \
	  $2 \
	  --do_sort_stats \
	  --do_compute_rep $PANDUMP)
    ./extract-ratingsFrepfile.pl pan2010.csv \
	$WIKITRUST/util/output/user_reputations.txt
    echo EDITLONG
    ./perf.src/perf < perf-editlong.txt
    echo TEXTLONG
    ./perf.src/perf < perf-textlong.txt
    wc perf-*.txt
    find $WIKITRUST/util/output/stats -name "*.gz" -exec gunzip -c {} \; | grep triangles > triangles.tmp
    echo "TOTAL TRIANGLES"
    awk '{ print $4 }' triangles.tmp | awk -F: '{total+=$1} END{print total}'
    echo "BAD TRIANGLES"
    awk '{ print $6 }' triangles.tmp | awk -F: '{total+=$1} END{print total}'
    rm -f triangles.tmp
}

# First split the wiki once
(cd $WIKITRUST/util ; rm -rf output*)
(cd $WIKITRUST/util ; time ./batch_process.py --cmd_dir ../analysis \
    --dir output --do_split $PANDUMP)

# And then do the experiments

####################################################################

for diff in {1..8}
do
  for mq in {1..9}
  do
    for ed in {1..5}
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


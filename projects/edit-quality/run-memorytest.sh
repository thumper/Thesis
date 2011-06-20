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
    (ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WIKITRUST/util ; \
	time ./batch_process.py --n_core $CORES --cmd_dir ../analysis \
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

doexpt "diff=1 precise match-quality=1 edist=1" "--diff 1 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=2 precise match-quality=1 edist=1" "--diff 2 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=3 precise match-quality=1 edist=1" "--diff 3 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=4 precise match-quality=1 edist=1" "--diff 4 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=5 precise match-quality=1 edist=1" "--diff 5 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=6 precise match-quality=1 edist=1" "--diff 6 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=7 precise match-quality=1 edist=1" "--diff 7 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=8 precise match-quality=1 edist=1" "--diff 8 --precise --match_quality 1 --edit_distance 1"
#doexpt "diff=9 precise match-quality=1 edist=1" "--diff 9 --precise --match_quality 1 --edit_distance 1"



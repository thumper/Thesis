#!/bin/bash
set -e
set -x

WIKITRUST=/store/thumper/research/WikiTrust
PANDUMP=/raid/thumper/pan2010dump.7z

function doexpt {
    echo "**************************************"
    echo "$1"
    echo
    (cd $WIKITRUST/util ; rm -rf output/blobs)
    (cd $WIKITRUST/util ; rm -rf output/buckets)
    (cd $WIKITRUST/util ; rm -rf output/sql)
    (cd $WIKITRUST/util ; rm -rf output/stats)
    (cd $WIKITRUST/util ; rm -rf output/user*)
    (cd $WIKITRUST/util ; time ./batch_process.py --cmd_dir ../analysis \
	  --dir output \
	  $2 \
          --do_compute_stats $PANDUMP)
    (cd $WIKITRUST/util ; time ./batch_process.py --cmd_dir ../analysis \
	  --dir output \
	  $2 \
	  --do_sort_stats \
	  --do_compute_rep $PANDUMP)
    ./extract-ratingsFrepfile.pl pan2010.csv \
	$WIKITRUST/util/output/user_reputations.txt
    ./perf.src/perf < perf-editlong.txt
    ./perf.src/perf < perf-textlong.txt
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

doexpt "LIVE" ""
doexpt "LIVE precise" "--precise"
doexpt "LIVE match-quality=1" "--match_quality 1"
doexpt "LIVE precise match-quality=1" "--precise --match_quality 1"
doexpt "LIVE match-quality=2" "--match_quality 2"
doexpt "LIVE precise match-quality=2" "--precise --match_quality 2"
doexpt "LIVE match-quality=3" "--match_quality 2"
doexpt "LIVE precise match-quality=3" "--precise --match_quality 3"

doexpt "LIVE edist=1" "--edit_distance 1"
doexpt "LIVE precise edist=1" "--precise --edit_distance 1"
doexpt "LIVE match-quality=1 edist=1" "--match_quality 1 --edit_distance 1"
doexpt "LIVE precise match-quality=1 edist=1" "--precise --match_quality 1 --edit_distance 1"
doexpt "LIVE match-quality=2 edist=1" "--match_quality 2 --edit_distance 1"
doexpt "LIVE precise match-quality=2 edist=1" "--precise --match_quality 2 --edit_distance 1"
doexpt "LIVE match-quality=3 edist=1" "--match_quality 3 --edit_distance 1"
doexpt "LIVE precise match-quality=3 edist=1" "--precise --match_quality 3 --edit_distance 1"

doexpt "LIVE edist=2" "--edit_distance 2"
doexpt "LIVE precise edist=2" "--precise --edit_distance 2"
doexpt "LIVE match-quality=1 edist=2" "--match_quality 1 --edit_distance 2"
doexpt "LIVE precise match-quality=1 edist=2" "--precise --match_quality 1 --edit_distance 2"
doexpt "LIVE match-quality=2 edist=2" "--match_quality 2 --edit_distance 2"
doexpt "LIVE precise match-quality=2 edist=2" "--precise --match_quality 2 --edit_distance 2"
doexpt "LIVE match-quality=3 edist=2" "--match_quality 3 --edit_distance 2"
doexpt "LIVE precise match-quality=3 edist=2" "--precise --match_quality 3 --edit_distance 2"

doexpt "LIVE edist=3" "--edit_distance 3"
doexpt "LIVE precise edist=3" "--precise --edit_distance 3"
doexpt "LIVE match-quality=1 edist=3" "--match_quality 1 --edit_distance 3"
doexpt "LIVE precise match-quality=1 edist=3" "--precise --match_quality 1 --edit_distance 3"
doexpt "LIVE match-quality=2 edist=3" "--match_quality 2 --edit_distance 3"
doexpt "LIVE precise match-quality=2 edist=3" "--precise --match_quality 2 --edit_distance 3"
doexpt "LIVE match-quality=3 edist=3" "--match_quality 3 --edit_distance 3"
doexpt "LIVE precise match-quality=3 edist=3" "--precise --match_quality 3 --edit_distance 3"

doexpt "LIVE edist=4" "--edit_distance 4"
doexpt "LIVE precise edist=4" "--precise --edit_distance 4"
doexpt "LIVE match-quality=1 edist=4" "--match_quality 1 --edit_distance 4"
doexpt "LIVE precise match-quality=1 edist=4" "--precise --match_quality 1 --edit_distance 4"
doexpt "LIVE match-quality=2 edist=4" "--match_quality 2 --edit_distance 4"
doexpt "LIVE precise match-quality=2 edist=4" "--precise --match_quality 2 --edit_distance 4"
doexpt "LIVE match-quality=3 edist=4" "--match_quality 3 --edit_distance 4"
doexpt "LIVE precise match-quality=3 edist=4" "--precise --match_quality 3 --edit_distance 4"

####################################################################

doexpt "diff=1" "-diff 1 "
doexpt "diff=1 precise" "-diff 1 --precise"
doexpt "diff=1 match-quality=1" "-diff 1 --match_quality 1"
doexpt "diff=1 precise match-quality=1" "-diff 1 --precise --match_quality 1"
doexpt "diff=1 match-quality=2" "-diff 1 --match_quality 2"
doexpt "diff=1 precise match-quality=2" "-diff 1 --precise --match_quality 2"
doexpt "diff=1 match-quality=3" "-diff 1 --match_quality 2"
doexpt "diff=1 precise match-quality=3" "-diff 1 --precise --match_quality 3"

doexpt "diff=1 edist=1" "-diff 1 --edit_distance 1"
doexpt "diff=1 precise edist=1" "-diff 1 --precise --edit_distance 1"
doexpt "diff=1 match-quality=1 edist=1" "-diff 1 --match_quality 1 --edit_distance 1"
doexpt "diff=1 precise match-quality=1 edist=1" "-diff 1 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=1 match-quality=2 edist=1" "-diff 1 --match_quality 2 --edit_distance 1"
doexpt "diff=1 precise match-quality=2 edist=1" "-diff 1 --precise --match_quality 2 --edit_distance 1"
doexpt "diff=1 match-quality=3 edist=1" "-diff 1 --match_quality 3 --edit_distance 1"
doexpt "diff=1 precise match-quality=3 edist=1" "-diff 1 --precise --match_quality 3 --edit_distance 1"

doexpt "diff=1 edist=2" "-diff 1 --edit_distance 2"
doexpt "diff=1 precise edist=2" "-diff 1 --precise --edit_distance 2"
doexpt "diff=1 match-quality=1 edist=2" "-diff 1 --match_quality 1 --edit_distance 2"
doexpt "diff=1 precise match-quality=1 edist=2" "-diff 1 --precise --match_quality 1 --edit_distance 2"
doexpt "diff=1 match-quality=2 edist=2" "-diff 1 --match_quality 2 --edit_distance 2"
doexpt "diff=1 precise match-quality=2 edist=2" "-diff 1 --precise --match_quality 2 --edit_distance 2"
doexpt "diff=1 match-quality=3 edist=2" "-diff 1 --match_quality 3 --edit_distance 2"
doexpt "diff=1 precise match-quality=3 edist=2" "-diff 1 --precise --match_quality 3 --edit_distance 2"

doexpt "diff=1 edist=3" "-diff 1 --edit_distance 3"
doexpt "diff=1 precise edist=3" "-diff 1 --precise --edit_distance 3"
doexpt "diff=1 match-quality=1 edist=3" "-diff 1 --match_quality 1 --edit_distance 3"
doexpt "diff=1 precise match-quality=1 edist=3" "-diff 1 --precise --match_quality 1 --edit_distance 3"
doexpt "diff=1 match-quality=2 edist=3" "-diff 1 --match_quality 2 --edit_distance 3"
doexpt "diff=1 precise match-quality=2 edist=3" "-diff 1 --precise --match_quality 2 --edit_distance 3"
doexpt "diff=1 match-quality=3 edist=3" "-diff 1 --match_quality 3 --edit_distance 3"
doexpt "diff=1 precise match-quality=3 edist=3" "-diff 1 --precise --match_quality 3 --edit_distance 3"

doexpt "diff=1 edist=4" "-diff 1 --edit_distance 4"
doexpt "diff=1 precise edist=4" "-diff 1 --precise --edit_distance 4"
doexpt "diff=1 match-quality=1 edist=4" "-diff 1 --match_quality 1 --edit_distance 4"
doexpt "diff=1 precise match-quality=1 edist=4" "-diff 1 --precise --match_quality 1 --edit_distance 4"
doexpt "diff=1 match-quality=2 edist=4" "-diff 1 --match_quality 2 --edit_distance 4"
doexpt "diff=1 precise match-quality=2 edist=4" "-diff 1 --precise --match_quality 2 --edit_distance 4"
doexpt "diff=1 match-quality=3 edist=4" "-diff 1 --match_quality 3 --edit_distance 4"
doexpt "diff=1 precise match-quality=3 edist=4" "-diff 1 --precise --match_quality 3 --edit_distance 4"

####################################################################

doexpt "diff=2" "-diff 2 "
doexpt "diff=2 precise" "-diff 2 --precise"
doexpt "diff=2 match-quality=1" "-diff 2 --match_quality 1"
doexpt "diff=2 precise match-quality=1" "-diff 2 --precise --match_quality 1"
doexpt "diff=2 match-quality=2" "-diff 2 --match_quality 2"
doexpt "diff=2 precise match-quality=2" "-diff 2 --precise --match_quality 2"
doexpt "diff=2 match-quality=3" "-diff 2 --match_quality 2"
doexpt "diff=2 precise match-quality=3" "-diff 2 --precise --match_quality 3"

doexpt "diff=2 edist=1" "-diff 2 --edit_distance 1"
doexpt "diff=2 precise edist=1" "-diff 2 --precise --edit_distance 1"
doexpt "diff=2 match-quality=1 edist=1" "-diff 2 --match_quality 1 --edit_distance 1"
doexpt "diff=2 precise match-quality=1 edist=1" "-diff 2 --precise --match_quality 1 --edit_distance 1"
doexpt "diff=2 match-quality=2 edist=1" "-diff 2 --match_quality 2 --edit_distance 1"
doexpt "diff=2 precise match-quality=2 edist=1" "-diff 2 --precise --match_quality 2 --edit_distance 1"
doexpt "diff=2 match-quality=3 edist=1" "-diff 2 --match_quality 3 --edit_distance 1"
doexpt "diff=2 precise match-quality=3 edist=1" "-diff 2 --precise --match_quality 3 --edit_distance 1"

doexpt "diff=2 edist=2" "-diff 2 --edit_distance 2"
doexpt "diff=2 precise edist=2" "-diff 2 --precise --edit_distance 2"
doexpt "diff=2 match-quality=1 edist=2" "-diff 2 --match_quality 1 --edit_distance 2"
doexpt "diff=2 precise match-quality=1 edist=2" "-diff 2 --precise --match_quality 1 --edit_distance 2"
doexpt "diff=2 match-quality=2 edist=2" "-diff 2 --match_quality 2 --edit_distance 2"
doexpt "diff=2 precise match-quality=2 edist=2" "-diff 2 --precise --match_quality 2 --edit_distance 2"
doexpt "diff=2 match-quality=3 edist=2" "-diff 2 --match_quality 3 --edit_distance 2"
doexpt "diff=2 precise match-quality=3 edist=2" "-diff 2 --precise --match_quality 3 --edit_distance 2"

doexpt "diff=2 edist=3" "-diff 2 --edit_distance 3"
doexpt "diff=2 precise edist=3" "-diff 2 --precise --edit_distance 3"
doexpt "diff=2 match-quality=1 edist=3" "-diff 2 --match_quality 1 --edit_distance 3"
doexpt "diff=2 precise match-quality=1 edist=3" "-diff 2 --precise --match_quality 1 --edit_distance 3"
doexpt "diff=2 match-quality=2 edist=3" "-diff 2 --match_quality 2 --edit_distance 3"
doexpt "diff=2 precise match-quality=2 edist=3" "-diff 2 --precise --match_quality 2 --edit_distance 3"
doexpt "diff=2 match-quality=3 edist=3" "-diff 2 --match_quality 3 --edit_distance 3"
doexpt "diff=2 precise match-quality=3 edist=3" "-diff 2 --precise --match_quality 3 --edit_distance 3"

doexpt "diff=2 edist=4" "-diff 2 --edit_distance 4"
doexpt "diff=2 precise edist=4" "-diff 2 --precise --edit_distance 4"
doexpt "diff=2 match-quality=1 edist=4" "-diff 2 --match_quality 1 --edit_distance 4"
doexpt "diff=2 precise match-quality=1 edist=4" "-diff 2 --precise --match_quality 1 --edit_distance 4"
doexpt "diff=2 match-quality=2 edist=4" "-diff 2 --match_quality 2 --edit_distance 4"
doexpt "diff=2 precise match-quality=2 edist=4" "-diff 2 --precise --match_quality 2 --edit_distance 4"
doexpt "diff=2 match-quality=3 edist=4" "-diff 2 --match_quality 3 --edit_distance 4"
doexpt "diff=2 precise match-quality=3 edist=4" "-diff 2 --precise --match_quality 3 --edit_distance 4"
doexpt "diff=2 match-quality=4 edist=4" "-diff 2 --match_quality 4 --edit_distance 4"
doexpt "diff=2 precise match-quality=4 edist=4" "-diff 2 --precise --match_quality 4 --edit_distance 4"

####################################################################


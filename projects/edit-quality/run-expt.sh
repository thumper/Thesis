#!/bin/bash
set -e
set -x

WIKITRUST=/store/thumper/research/WikiTrust
PANDUMP=/raid/thumper/pan2010dump.7z

function doexpt {
    echo "**************************************"
    echo "$1"
    echo
    (cd $WIKITRUST/util ; rm -rf output*)
    (cd $WIKITRUST/util ; time ./batch_process.py --cmd_dir ../analysis --dir output \
          --do_split --do_compute_stats --do_sort_stats \
	  $2 \
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

doexpt "LIVE" ""
doexpt "LIVE precise" "--precise"
doexpt "LIVE match-quality=1" "--match_quality 1"
doexpt "LIVE precise match-quality=1" "--precise --match_quality 1"

doexpt "LIVE edist=1" "--edit_distance 1"
doexpt "LIVE precise edist=1" "--precise --edit_distance 1"
doexpt "LIVE match-quality=1 edist=1" "--match_quality 1 --edit_distance 1"
doexpt "LIVE precise match-quality=1 edist=1" "--precise --match_quality 1 --edit_distance 1"

doexpt "LIVE edist=2" "--edit_distance 2"
doexpt "LIVE precise edist=2" "--precise --edit_distance 2"
doexpt "LIVE match-quality=1 edist=2" "--match_quality 1 --edit_distance 2"
doexpt "LIVE precise match-quality=1 edist=2" "--precise --match_quality 1 --edit_distance 2"

doexpt "LIVE edist=3" "--edit_distance 3"
doexpt "LIVE precise edist=3" "--precise --edit_distance 3"
doexpt "LIVE match-quality=1 edist=3" "--match_quality 1 --edit_distance 3"
doexpt "LIVE precise match-quality=1 edist=3" "--precise --match_quality 1 --edit_distance 3"


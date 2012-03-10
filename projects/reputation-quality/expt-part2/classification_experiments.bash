#!/bin/bash

set -x
set -e

WEKA=/home/thumper/Downloads/tmp/weka-3-7-5
DATASET_DIR=../data
RESULTS_DIR=results

mkdir -p $RESULTS_DIR

do_the_monkey_dance() {
    local dataset=$1
    local results=$2
    # use "-i" instead of "-p 1" to get human readable output
    ## normal validation
    java -Xmx2G -classpath $WEKA/weka.jar weka.classifiers.meta.FilteredClassifier -t $dataset -p 1 -F "weka.filters.unsupervised.attribute.Remove -R 1,2,3" -W weka.classifiers.trees.RandomForest -- -I 500 > $results.preds
    ## select only non-anonymous edits.
    ## Except that this gives an error about the test instance not being available.
    ## Instead, edit complete-features.arff, and do cmd: :g/\v^\d+,\d+,\d+,true,/d
    ## and run normal validation
    ## position 39 = reputation
    #java -Xmx2G -classpath $WEKA/weka.jar weka.classifiers.meta.FilteredClassifier -t $dataset -i -F "weka.filters.MultiFilter -F \"weka.filters.unsupervised.instance.RemoveWithValues -C 4 -L last\" -F \"weka.filters.unsupervised.attribute.Remove -R 1,2,3,4,39\"" -W weka.classifiers.trees.RandomForest -- -I 500 > $results.preds
    python graphs.py $results.preds > $results.prcurve.dat
    python to_perf.py $results.preds > $results.perf_preds
    cat $results.perf_preds | awk '{ print $2" "$1 }' > $results.perf_preds_reverse
    java -jar auc.jar $results.perf_preds_reverse list > $results.auc
}

for DATASET in complete-features.arff ; do
    DATASET_PATH=$DATASET_DIR/$DATASET
    DATASET_BASE=${DATASET/.arff/}

    do_the_monkey_dance ${DATASET_PATH} $RESULTS_DIR/${DATASET_BASE}.randomforest.i500

done

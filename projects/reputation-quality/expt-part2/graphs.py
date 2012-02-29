#!/usr/bin/python

import sys

data = open(sys.argv[1], 'r').read().splitlines()
data = data[5:-1]

preds = []

for sample in data:
    s = sample.replace('+', ' ').split()
    actual_class = s[1][2:] in ('yes', 'True', 'true')
    prediction_class = s[2][2:] in ('yes', 'True', 'true')
    prediction_confidence = float(s[3])
    prediction = prediction_confidence if prediction_class else 1 - prediction_confidence
    preds.append((prediction, actual_class))

del data
preds = sorted(preds)

for threshold in [x/1000. for x in range(1000)]:
    tp = 0
    fp = 0
    tn = 0
    fn = 0
    for pred in preds:
        if pred[0] < threshold:
            if pred[1]:
                fn += 1
            else:
                tn += 1
        else:
            if pred[1]:
                tp += 1
            else:
                fp += 1
    precision = float(tp) / (tp + fp) if tp > 0 or fp > 0 else 0.
    recall = float(tp) / (tp + fn) if tp > 0 or fn > 0 else 0.

    print recall, precision

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
    print int(actual_class), prediction

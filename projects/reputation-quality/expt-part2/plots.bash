#!/bin/bash

cat <<EOF | gnuplot
set term postscript eps enhanced color "Times-Roman" 20
set output 'pr_systems_historic.eps'
set ylabel 'Precision'
set xlabel 'Recall'
set size square
set key left bottom
plot \
	'complete-features.randomforest.i500.prcurve.dat' title 'WikiTrust+rep' with l lw 2
EOF



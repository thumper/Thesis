set xlabel "deletions+moves"
set ylabel "text additions"
set xrange [0:1e6]
set yrange [0:1e6]
set term postscript eps enhanced color
set nokey
set output "../usercontrib-data/plot-edit-text.eps"
plot "../usercontrib-data/contrib-data-clean.txt" using ($4 - $10):10
quit

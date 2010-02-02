set xlabel "number of edits"
set ylabel "users"
set logscale xy
set xrange [1:397]
set term postscript eps enhanced color
set nokey
set output "../usercontrib-data/plot-hist-numedits.eps"
plot "../usercontrib-data/hist-single-numedits.txt"
quit

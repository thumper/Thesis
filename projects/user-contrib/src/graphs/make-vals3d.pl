#!/usr/bin/perl -w
use strict;

foreach my $in (@ARGV) {
    my $out = $in;
    $out =~ s/\.dat/\.png/;
    if ($in =~ m/\bhist-\w+\-(\w+)-(\w+)\b/) {
	plot($in, $out, $1, $2);
    }
}
exit(0);


sub plot {
    my ($in, $out, $col1name, $col2name) = @_;

    open(my $gp, "| gnuplot") || die "exec(gnuplot): $!";
#set yrange [0:10]
#set logscale y
##set style data linespoints
#set pointsize 2
#set term postscript eps enhanced color
    print $gp <<"_END_GNUPLOT_";
set xlabel "$col1name"
set ylabel "$col2name"
set hidden3d
set term png
set nokey
set output "$out"
set view 70,10
set logscale z
splot '$in' with lines
quit
_END_GNUPLOT_
    close($gp);
}


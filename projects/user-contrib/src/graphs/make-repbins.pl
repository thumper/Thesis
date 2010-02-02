#!/usr/bin/perl -w

use strict;

my $file = shift @ARGV;

open(my $in, "<", $file) || die "open: $!";
my $line = <$in>;
close($in);
my @headers = split(' ', $line);
for (my $x = 1; $x < @headers; $x++) {
    for (my $y = $x+1; $y < @headers; $y++) {
    	my $out = "out-$headers[$x]-$headers[$y].png";
        plot($out, $file, $x, $y, $headers[$x], $headers[$y], 0);
    	$out = "log-$headers[$x]-$headers[$y].png";
        plot($out, $file, $x, $y, $headers[$x], $headers[$y], 1);
    }
}
exit(0);

sub plot {
    my ($output, $file, $col1, $col2, $col1name, $col2name, $log) = @_;

    # gnuplot uses 1-based counting for columns
    $col1++;
    $col2++;

    open(my $gp, "| gnuplot") || die "exec(gnuplot): $!";
#set yrange [0:10]
#set logscale y
##set style data linespoints
#set pointsize 2
#set format y "%g"
#set term postscript eps enhanced color
#set output "$plotout"
    if ($log) {
	print $gp "set logscale y\n";
	print $gp "set logscale x\n";
    }
    print $gp <<"_END_GNUPLOT_";
set xlabel "$col1name"
set ylabel "$col2name"
set term png
set output "$output"
plot "$file" using $col1:$col2 title "$col1name x $col2name";
quit
_END_GNUPLOT_
    close($gp);
}


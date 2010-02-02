#!/usr/bin/perl -w

use strict;

die "wrong number of args" if @ARGV < 2;
my $dir = shift @ARGV;
my $file = $ARGV[0];

my %range = (
    'editlong'		=> '[-5e+5:5e+5]',
    'editlong1'		=> '[-5e+6:5e+6]',
    'editonly'		=> '[0:2e+6]',
    'numedits'		=> '[0:1e+5]',
    'reputation'	=> '[-5e+5:1e+6]',
    'reputationexact'	=> '[0:25000]',
    'revisions'		=> '[0:2e+6]',
    'textonly'		=> '[0:5e+5]',
    'textlong'		=> '[0:3e+5]',
    'textwithpunish1'	=> '[-1e+6:1e+6]',
    'textwithpunish'	=> '[-2e+5:4e+5]',
);


open(my $in, "<", $file) || die "open: $!";
my $line = <$in>;
close($in);
my @headers = split(' ', $line);
for (my $x = 1; $x < @headers; $x++) {
    for (my $y = $x+1; $y < @headers; $y++) {
    	my $out = "$dir/full-$headers[$x]-$headers[$y].png";
        plot($out, \@ARGV, $x, $y, $headers[$x], $headers[$y], 0);
    	$out = "$dir/zoom-$headers[$x]-$headers[$y].png";
        plot($out, \@ARGV, $x, $y, $headers[$x], $headers[$y], 1);
    }
}
exit(0);

sub plot {
    my ($output, $files, $col1, $col2, $col1name, $col2name, $zoom) = @_;

    # gnuplot uses 1-based counting for columns
    $col1++;
    $col2++;

    open(my $gp, "| gnuplot") || die "exec(gnuplot): $!";
#set yrange [0:10]
#set logscale y
##set style data linespoints
#set pointsize 2
#set term postscript eps enhanced color
    if ($zoom) {
        die "bad col: $col2name" if !exists $range{$col2name};
        die "bad col: $col1name" if !exists $range{$col1name};
	print $gp "set yrange ", $range{$col2name}, "\n";
	print $gp "set xrange ", $range{$col1name}, "\n";
    }
    print $gp <<"_END_GNUPLOT_";
set xlabel "$col1name"
set ylabel "$col2name"
set format x "%g"
set format y "%g"
set term png
set nokey
set output "$output"
_END_GNUPLOT_
    print $gp "plot ", join(', ', map { "\"$_\" using $col1:$col2" } @$files), "\n";
    print $gp "quit\n";
    close($gp);
}


#!/usr/bin/perl -w

use strict;

die "wrong number of args" if @ARGV != 1;

my $dir = shift @ARGV;

my %range = (
    'editlong'		=> '[-5e+5:5e+5]',
    'editlong1'		=> '[-5e+6:5e+6]',
    'editonly'		=> '[0:2e+6]',
    'reputation'	=> '[-5e+5:1e+6]',
    'reputationexact'	=> '[0:25000]',
    'tenrevs'		=> '[0:2e+6]',
    'textonly'		=> '[0:5e+5]',
    'textlong'		=> '[0:3e+5]',
    'textwithpunish1'	=> '[-1e+6:1e+6]',
    'textwithpunish'	=> '[-2e+5:4e+5]',
);

my $file = "$dir/contrib-data-clean.txt";
open(my $in, "<", $file) || die "open: $!";
my $line = <$in>;
close($in);
my @headers = split(' ', $line);

my @files = (
	["users"	=> "$dir/contrib-data-clean.txt"],
#	["bots"		=> "$dir/contrib-bots.txt"],
	);

plot("$dir/score-zoom-revisions-textonly.eps", \@files,
	"textonly", "tenrevs",
	"TextOnly", "TenRevs",
	1);
plot("$dir/score-zoom-editonly-editlong.eps", \@files,
	"editonly", "editlong",
	"EditOnly", "EditLong",
	1);
plot("$dir/score-zoom-textonly-textlong.eps", \@files,
	"textonly", "textlong",
	"TextOnly", "TextLong",
	1);
plot("$dir/score-zoom-textonly-textwithpunish.eps", \@files,
	"textonly", "textwithpunish",
	"TextOnly", "TextWithPunish",
	1);

plot3d("$dir/hist-pctl-editlong-textlong.dat",
	"$dir/prct-editlong-textlong.eps",
	"EditLong", "TextLong");
plot3d("$dir/hist-pctl-editlong-textwithpunish.dat",
	"$dir/prct-editlong-textwithpunish.eps",
	"EditLong", "TextWithPunish");
plot3d("$dir/hist-pctl-editlong-reputation.dat",
	"$dir/prct-editlong-reputation.eps",
	"EditLong", "Reputation");

exit(0);

sub col {
    for (my $i = 0; $i < @headers; $i++) {
        return $i if $headers[$i] eq $_[0];
    }
    return undef;
}

sub plot {
    my ($output, $files, $col1name, $col2name,
    	$col1label, $col2label, $zoom) = @_;

    # gnuplot uses 1-based counting for columns
    my $col1 = col($col1name) + 1;
    my $col2 = col($col2name) + 1;

    open(my $gp, "| gnuplot") || die "exec(gnuplot): $!";
#set yrange [0:10]
#set logscale y
##set style data linespoints
#set pointsize 2
#set term postscript eps enhanced color
    if ($zoom) {
	print $gp "set yrange ", $range{$col2name}, "\n";
	print $gp "set xrange ", $range{$col1name}, "\n";
    }
    print $gp <<"_END_GNUPLOT_";
set xlabel "$col1label"
set ylabel "$col2label"
set format x "%g"
set format y "%g
set term postscript eps enhanced color
set nokey
set output "$output"
_END_GNUPLOT_
    print $gp "plot ",
    	join(', ', map {
		'"'.
		$_->[1].
		"\" using $col1:$col2 title \"".
		$_->[0].
		'"'
		} @$files), "\n";
    print $gp "quit\n";
    close($gp);
}


sub plot3d {
    my ($in, $out, $col1name, $col2name) = @_;

    warn "generating $out\n";
    open(my $gp, "| gnuplot") || die "exec(gnuplot): $!";
#set yrange [0:10]
#set logscale y
##set style data linespoints
#set pointsize 2
#set pm3d
    print $gp <<"_END_GNUPLOT_";
set xlabel "$col1name"
set ylabel "$col2name"
set hidden3d
set term postscript eps enhanced color
set output "$out"
set view 60,330
set nokey
splot '$in' with lines
quit
_END_GNUPLOT_
    close($gp);
}


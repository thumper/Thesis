#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Math::Round qw/nlowmult/;
use List::Util qw/sum/;
use constant INCREMENT => 1;		# need to fix code, too

my %optctl = (
    log => 0,
);
GetOptions(\%optctl, "log");

die "wrong number of args" if @ARGV != 2;
my ($file, $outdir) = @ARGV;

my @minVal;

open(my $in, "<", $file) || die "open($file): $!";
my $line = <$in>;
my @headers = split(' ', $line);
my %users;
while (<$in>) {
    chomp;
    my @fields = split(' ');
    my $uid = shift @fields;
    foreach (@fields) {
	$_ = $_ + 0;
	$_ = log10($_) if $optctl{log};
    }
    for (my $i = 1; $i < @headers; $i++) {
	$minVal[$i] = mymin($minVal[$i], $fields[$i-1]);
    }
    $users{$uid} = \@fields;
}
close($in);

my @binWidth;
my @range;
for (my $i = 0; $i < @headers - 1; $i++) {
    my @vals = sort { $a <=> $b } (map { $users{$_}->[$i] } (keys %users));
    $binWidth[$i] = computeBestBin(@vals);
    my %vals;
    foreach (@vals) {
	my $x = nlowmult($binWidth[$i], $_);
	$vals{$x}++;
    }
    @vals = sort {$a <=> $b} keys %vals;
    my $minrange = $vals[0];
    for (my $j = 0; $j < @vals; $j++) {
	if ($vals{$vals[$j]} > 30) {
	    $minrange = $vals[$j];
	    last;
	}
    }
    my $maxrange = $vals[-1];
    for (my $j = @vals - 1; $j >= 0; $j--) {
	if ($vals{$vals[$j]} > 30) {
	    $maxrange = $vals[$j];
	    last;
	}
    }
    $range[$i] = [$minrange, $maxrange];

    open(my $hist, ">", "$outdir/hist-single-$headers[$i+1].txt") || die "open: $!";
    foreach (sort { $a <=> $b } keys %vals) {
	next if $_ < $minrange;
	next if $_ > $maxrange;
	print $hist "$_\t$vals{$_}\n";
    }
    close($hist);
    warn "column $headers[$i+1]: binWidth = $binWidth[$i]\n";
}



my $log = "";
$log = "-log" if $optctl{log};

for (my $x = 1; $x < @headers; $x++) {
    for (my $y = $x+1; $y < @headers; $y++) {
    	my $out = "$outdir/hist-vals$log-$headers[$x]-$headers[$y].dat";
        hist($out, $x, $y, $headers[$x], $headers[$y], 0);
    }
}
exit(0);

sub hist {
    my ($output, $col1, $col2) = @_;

    # swap cols to be alphabetical
    if ($headers[$col2] lt $headers[$col1]) {
	my $tmp = $col1;
	$col1 = $col2;
	$col2 = $tmp;
    }
    my $col1name = $headers[$col1--];
    my $col2name = $headers[$col2--];


    my %data;
    my %ydata;
    while (my ($uid, $vals) = each %users) {
	my $x = $vals->[$col1];
	my $y = $vals->[$col2];
	# put into histogram range
	$x = nlowmult($binWidth[$col1], $x);
	next if $x < $range[$col1]->[0];
	next if $x > $range[$col1]->[1];
	$y = nlowmult($binWidth[$col2], $y);
	next if $y < $range[$col2]->[0];
	next if $y > $range[$col2]->[1];
	$ydata{$y} = 1;
	$data{$x}->{$y}++;
    }
    # find bounds
    my @xvals = sort { $a <=> $b } keys %data;
    my @yvals = sort { $a <=> $b } keys %ydata;
    my $minx = $xvals[0];
    my $maxx = $xvals[-1];
    my $miny = $yvals[0];
    my $maxy = $yvals[-1];
    for (my $x = 0; $x < @xvals; $x++) {
	for (my $y = 0; $y < @yvals; $y++) {
	    if (($data{$xvals[$x]}->{$yvals[$y]}||0) > 10) {
	    	$minx = $xvals[$x];
		$x = @xvals;
		$y = @yvals;
	    }
	}
    }
    for (my $x = @xvals-1; $x >= 0; $x--) {
	for (my $y = 0; $y < @yvals; $y++) {
	    if (($data{$xvals[$x]}->{$yvals[$y]}||0) > 10) {
	    	$maxx = $xvals[$x];
		$x = 0;
		$y = @yvals;
	    }
	}
    }
    for (my $y = 0; $y < @yvals; $y++) {
	for (my $x = 0; $x < @xvals; $x++) {
	    if (($data{$xvals[$x]}->{$yvals[$y]}||0) > 10) {
	    	$miny = $yvals[$y];
		$x = @xvals;
		$y = @yvals;
	    }
	}
    }
    for (my $y = @yvals - 1; $y >= 0; $y--) {
	for (my $x = 0; $x < @xvals; $x++) {
	    if (($data{$xvals[$x]}->{$yvals[$y]}||0) > 10) {
	    	$maxy = $yvals[$y];
		$x = @xvals;
		$y = 0;
	    }
	}
    }


    open(my $out, ">", $output) || die "open: $!";
    foreach my $x (sort { $a <=> $b } keys %data) {
    	next if $x < $minx;
    	next if $x > $maxx;
	foreach my $y (sort { $a <=> $b } keys %ydata) {
	    next if $y < $miny;
	    next if $y > $maxy;
	    print $out join("\t", $x, $y, ($data{$x}->{$y} || 0.0)), "\n";
	}
	print $out "\n";
    }
    close($out);
}

sub mymin {
    return $_[1] if !defined $_[0];
    return ($_[0] < $_[1] ? $_[0] : $_[1]);
}

sub computeBestBin {
    my @diffs;
    for (my $i = 1; $i < @_; $i++) {
	$diffs[$i-1] = $_[$i] - $_[$i-1];
    }
    @diffs = sort { $a <=> $b } @diffs;

    my $minLimit = int(@_ / 1000);
    my $maxLimit = int(@_ / 3);

    my $minBin = $diffs[0];
    my $maxBin = ($_[-1] - $_[0]) / 50;
    while (1) {
        my $binWidth = ($maxBin + $minBin) / 2;
	$binWidth = int($binWidth) if $binWidth >= 1.0;
	return 0.5 if $binWidth < 0.5;
	warn "\tTrying width $binWidth\n";
	my %vals;
	foreach (@_) {
	    my $x = int($_ / $binWidth);
	    $vals{$x}++;
	}
	my $bins = 0;
	my $bigBins = 0;
	foreach (keys %vals) {
	    $bins++ if $vals{$_} > $minLimit;
	    $bigBins++ if $vals{$_} > $maxLimit;
	}
	warn "\tFound $bins bins with over $minLimit users, and $bigBins bins over $maxLimit\n";
	return $binWidth if $bigBins == 0 && $bins > 20;
	return $binWidth if $bigBins == 0;
	if ($bins < 20 || $bigBins > 0) {
	    $maxBin = $binWidth;
	} else {
	    $minBin = $binWidth;
	}
    }
}


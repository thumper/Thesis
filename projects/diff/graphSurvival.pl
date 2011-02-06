#!/usr/bin/perl

use strict;
use warnings;
use List::Util qw(min sum);
use constant KEEP_POINTS => 20;

my (%track, $revid, %current);
while (<>) {
    next if !m/^===/ && !m/^\d/;
    chomp;
    if (m/^====== revid (\d+)$/) {
	processRevs(\%track, \%current);
    }
    if (m/^(\d+)\t(\d+)$/) {
	$current{$1} = $2;
    }
}
processRevs(\%track, \%current);
printRevs(\%track);
exit(0);

sub processRevs {
    my ($track, $current) = @_;

    foreach my $revid (keys %$track) {
	my $seen = $current{$revid} || 0;
	my $history = $track->{$revid};
	push @$history, $seen;
	delete $current->{$revid}
    }
    # what's left in $current isn't in $track, so move it over
    foreach my $revid (keys %$current) {
	$track->{$revid} = [ $current->{$revid} ];
	delete $current->{$revid};
    }
}

sub printRevs {
    my ($track) = @_;
    foreach my $revid (sort { $a <=> $b } keys %$track) {
	my $history = $track->{$revid};
	writeHistory($revid, $history);
    }
}

sub writeHistory {
    my ($revid, $history) = @_;

    # Don't bother graphing small contributions
    return if $history->[0] < 10;
    return if @$history <= KEEP_POINTS;

    $#$history = min(KEEP_POINTS, $#$history);

    my $print = 0;
    my $lastVal = $history->[0];

    my $file = "data-Survival-$revid.txt";
    open(OUTPUT, ">$file") || die "open: $!";
    print OUTPUT "Versions\tTextSeen\n";
    for (my $i = 0; $i < scalar(@$history); $i++) {
	print OUTPUT "$i\t".$history->[$i]."\n";
	$print = 1 if $history->[$i] != $lastVal;
	$lastVal = $history->[$i];
    }
    my $quality = findQuality($history);
    close(OUTPUT);
    my $tofile = "set term postscript eps enhanced color\nset output 'graph.eps'\n";
    # TODO: insert ${tofile} just before 'plot' to plot to a file.
    system("echo \"plot '$file' using 1:2 title 'Text survival for rev $revid' $quality\npause 3\n\" | gnuplot")
	if $print;
}

sub findQuality {
    my $history = shift @_;

    my $sum = sum @$history[0..KEEP_POINTS];
    my $first = $history->[0];

    my $func = sub {
	my $alpha = shift @_;
	return (1-$alpha) * $sum - $first * (1 - ($alpha**(KEEP_POINTS+1)));
    };
    my $funcPrime = sub {
	my $alpha = shift @_;
	return -$sum + $first * (KEEP_POINTS+1) * ($alpha**KEEP_POINTS);
    };

    my $alpha = 0.0;
    foreach (1..20) {
	$alpha = $alpha - ($func->($alpha) / $funcPrime->($alpha));
    }
    my $trunc = int($alpha * 1000) / 1000.0;
    return ", $first * ($alpha**x) title 'survival quality = $trunc' ";
}




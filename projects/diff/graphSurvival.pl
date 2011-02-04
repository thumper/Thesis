#!/usr/bin/perl

use strict;
use warnings;

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
exit(0);

sub processRevs {
    my ($track, $current) = @_;

    foreach my $revid (keys %$track) {
	my $seen = $current{$revid} || 0;
	my $history = $track->{$revid};
	push @$history, $seen;
	if (@$history >= 20) {
	    writeHistory($revid, $history);
	    # we don't keep track past a certain amount
	    delete $track->{$revid};
	}
	delete $current->{$revid}
    }
    # what's left in $current isn't in $track, so move it over
    foreach my $revid (keys %$current) {
	$track->{$revid} = [ $current->{$revid} ];
	delete $current->{$revid};
    }
}

sub writeHistory {
    my ($revid, $history) = @_;

    my $file = "data-Survival-$revid.txt";
    open(OUTPUT, ">$file") || die "open: $!";
    print OUTPUT "Versions\tTextSeen\n";
    for (my $i = 0; $i < @$history; $i++) {
	print OUTPUT "$i\t".$history->[$i]."\n";
    }
    close(OUTPUT);
    system("echo plot \"'$file' using 1:2\npause 3\n\" | gnuplot");
}



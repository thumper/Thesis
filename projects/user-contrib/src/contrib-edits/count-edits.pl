#!/usr/bin/perl -w

use strict;

my %users;

while (<>) {
    if (m/^TextLife\b.*\buid0: (\d+)\b/) {
	my $uid = $1;
	next if $uid == 0;
	$users{$uid}++;
    }
}

foreach my $uid (keys %users) {
    print "Uid $uid\tName \"X[$uid]\"\tReputation 0\tContribution $users{$uid}\n";
}
exit(0);


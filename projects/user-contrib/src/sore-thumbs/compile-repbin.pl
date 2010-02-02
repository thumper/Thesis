#!/usr/bin/perl -w

# args are the contribution files in any order

use strict;
use Getopt::Long;

my %users;

for (my $fnum = 0; $fnum < @ARGV; $fnum++) {
    my $file = $ARGV[$fnum];
    open(INPUT, "<", $file) || die "open($file): $!";
    while (<INPUT>) {
	if (m/\bUid (\d+).*\bReputation (\d+).*\bContribution ([0-9\.\-]+)\b/) {
	    $users{$1} = "" if !exists $users{$1};
	    $users{$1} .= $2.":".$3;
	}
    }
    close(INPUT);
}

warn "Data NumUsers ", scalar(keys %users), "\n";

print join("\t", "uid", "repbin", "repexact"), "\n";
while (my ($uid, $val) = each %users) {
    my @contribs = split(/:/, $val);
    print join("\t", $uid, @contribs),"\n";
}
exit(0);


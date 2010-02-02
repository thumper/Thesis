#!/usr/bin/perl -w

use strict;

die "wrong number of args" if @ARGV != 2;
my ($uids, $stats) = @ARGV;

my %uids;
open(my $u, "<", $uids) || die "open: $!";
while (<$u>) {
    chomp;
    $uids{$_} = 1;
}
close($u);

my $io = "";
$io .= ":gzip" if $stats =~ m/\.gz$/;
open(my $in, "<$io", $stats) || die "open: $!";
while (<$in>) {
    next if !m/^(?:EditLife|EditInc)/;
    my @fields = split(' ');
    next if !exists $uids{$fields[7]};
    if ($fields[0] eq 'EditInc') {
	# EditInc  980146867 PageId: 15 JudgedRev: 166547 JudgedUid: 90 JudgeRev: 233200 JudgeUid: 0 Dbefore:  219.00 Djudged:  218.00 Delta:    3.00
	delete $uids{$fields[7]} if $fields[17] != 0.0;
	#print $_ if $fields[17] != 0.0;
    } elsif ($fields[0] eq 'EditLife') {
	# EditLife  980146867 PageId: 15 JudgedRev: 233200 JudgedUid: 0 NJudges: 2 Delta: 218.00 AvgSpecQ: -0.98050
	delete $uids{$fields[7]} if $fields[11] != 0.0;
	#print $_ if $fields[11] != 0.0;
    }
}
close($in);

foreach my $uid (keys %uids) {
    print $uid, "\n";
}

exit(0);


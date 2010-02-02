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
    next if !m/^(?:TextLife|TextInc)/;
    my @fields = split(' ');
    next if !exists $uids{$fields[7]};
    if ($fields[0] eq 'TextInc') {
	# TextInc  980146867 PageId: 15 JudgedRev: 166547 JudgedUid: 90 JudgeRev: 233200 JudgeUid: 0 t: 4 q: 0
	delete $uids{$fields[7]} if $fields[13] != 0;
	#print $_ if $fields[13] != 0;
    } elsif ($fields[0] eq 'TextLife') {
	# TextLife  980146832 PageId: 14 JudgedRev: 233198 JudgedUid: 0 NJudges: 2 NewText: 217 Life: 0
	delete $uids{$fields[7]} if $fields[11] != 0;
	#print $_ if $fields[11] != 0;
    }
}
close($in);

foreach my $uid (keys %uids) {
    print $uid, "\n";
}

exit(0);


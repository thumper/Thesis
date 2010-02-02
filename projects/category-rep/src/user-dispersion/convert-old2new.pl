#!/usr/bin/perl -w

use strict;
use Getopt::Long;

my %optctl = (
    mode => 'text',
);

GetOptions(\%optctl, "mode=s");

while (<>) {
    next if ($optctl{mode} eq 'text') && !m/^TextInc/;
    next if ($optctl{mode} eq 'edit') && !m/^EditInc/;
    my @fields = split(' ');
    if ($fields[0] eq 'TextLife') {
	# TextLife  980146832 PageId: 14 JudgedRev: 233198 JudgedUid: 0 NJudges: 2 NewText: 217 Life: 0
	printf "TextLife %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" NJudges: %d NewText: %d Life: %d\n",
		$fields[1], $fields[3], $fields[5], $fields[7], $fields[7], $fields[9], $fields[11], $fields[13];
    } elsif ($fields[0] eq 'TextInc') {
	# TextInc  980146867 PageId: 15 JudgedRev: 166547 JudgedUid: 90 JudgeRev: 233200 JudgeUid: 0 t: 4 q: 0
	printf "TextInc %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" rev1: %d uid1: %d uname1: \"User[%d]\" text: %d left: %d n01: 1 t01: 0\n",
		$fields[1], $fields[3], $fields[5], $fields[7], $fields[7], $fields[9], $fields[11], $fields[11], $fields[13], $fields[15];
    } elsif ($fields[0] eq 'EditInc') {
	# EditInc  980146867 PageId: 15 JudgedRev: 166547 JudgedUid: 90 JudgeRev: 233200 JudgeUid: 0 Dbefore:  219.00 Djudged:  218.00 Delta:    3.00
	printf "EditInc %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" rev1: %d uid1: %d uname1: \"User[%d]\" rev2: 0 uid2: 0 uname2: \"X[0]\" d01: %f d02: %f d12: %f n01: 1 n12: 1 t01: 0 t12: 0\n",
		$fields[1], $fields[3], $fields[5], $fields[7], $fields[7], $fields[9], $fields[11], $fields[11], $fields[13], $fields[15], $fields[17];
    } elsif ($fields[0] eq 'EditLife') {
	# EditLife  980146867 PageId: 15 JudgedRev: 233200 JudgedUid: 0 NJudges: 2 Delta: 218.00 AvgSpecQ: -0.98050
	printf "EditLife %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" NJudges: %d Delta: %f AvgSpecQ: %f\n",
		$fields[1], $fields[3], $fields[5], $fields[7], $fields[7], $fields[9], $fields[11], $fields[13];
    }
}
exit(0);


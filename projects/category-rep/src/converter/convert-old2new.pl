#!/usr/bin/perl -w

use strict;

# NOTE: This converts the old format to the new format.
# It tries to figure out the distance between revisions,
# but only does a loose approximation within each second.
# It will be wrong when there are multiple revisions by
# the judging uid.

my %pageCount;
my %revs;
my @buffer;
my $eof = 0;

while (my $fields = getline()) {
    if ($fields->[0] eq 'TextLife') {
	# TextLife  980146832 PageId: 14 JudgedRev: 233198 JudgedUid: 0 NJudges: 2 NewText: 217 Life: 0
	printf "TextLife %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" NJudges: %d NewText: %d Life: %d\n",
		$fields->[1], $fields->[3], $fields->[5], $fields->[7], $fields->[7], $fields->[9], $fields->[11], $fields->[13];
    } elsif ($fields->[0] eq 'TextInc') {
	# TextInc  980146867 PageId: 15 JudgedRev: 166547 JudgedUid: 90 JudgeRev: 233200 JudgeUid: 0 t: 4 q: 0
	printf "TextInc %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" rev1: %d uid1: %d uname1: \"User[%d]\" text: %d left: %d n01: %d t01: 0\n",
		$fields->[1], $fields->[3], $fields->[5], $fields->[7], $fields->[7], $fields->[9], $fields->[11], $fields->[11], $fields->[13], $fields->[15], (getRevNum($fields->[3], $fields->[9]) - getRevNum($fields->[3], $fields->[5]));
    } elsif ($fields->[0] eq 'EditInc') {
	# EditInc  980146867 PageId: 15 JudgedRev: 166547 JudgedUid: 90 JudgeRev: 233200 JudgeUid: 0 Dbefore:  219.00 Djudged:  218.00 Delta:    3.00
	printf "EditInc %d PageId: %d rev0: %d uid0: %d uname0: \"X[%d]\" rev1: %d uid1: %d uname1: \"User[%d]\" rev2: 0 uid2: 0 uname2: \"User[0]\" d01: %f d02: %f d12: %f n01: 1 n12: %d t01: 0 t12: 0\n",
		$fields->[1], $fields->[3], $fields->[5], $fields->[7], $fields->[7], $fields->[9], $fields->[11], $fields->[11], $fields->[13], $fields->[15], $fields->[17], (getRevNum($fields->[3], $fields->[9]) - getRevNum($fields->[3], $fields->[5]));
    } elsif ($fields->[0] eq 'EditLife') {
	# EditLife  980146867 PageId: 15 JudgedRev: 233200 JudgedUid: 0 NJudges: 2 Delta: 218.00 AvgSpecQ: -0.98050
	printf "EditLife %d PageId: %d rev0: %d uid0: %d uname0: \"User[%d]\" NJudges: %d Delta: %f AvgSpecQ: %f\n",
		$fields->[1], $fields->[3], $fields->[5], $fields->[7], $fields->[7], $fields->[9], $fields->[11], $fields->[13];
    }
}
exit(0);

sub getRevNum {
    my ($pageId, $revId) = @_;
    return $revs{$revId} if exists $revs{$revId};
    $revs{$revId} = ++$pageCount{$pageId};
    return $revs{$revId};
}

sub getline {
    if ((@buffer < 2) && !$eof) {
	%pageCount = ();
	%revs = ();
	# need to refill the buffer
	$eof = 1;
	while (defined ($_ = <>)) {
	    next if m/^Page:/;
	    chomp;
	    my @fields = split(' ');
	    push @buffer, \@fields;
	    if ((@buffer >= 2) && ($buffer[-1]->[1] != $buffer[-2]->[1])) {
		$eof = 0;
		last;
	    }
	}
	# figure out what revisions are mentioned,
	# but don't look at the last line read in,
	# which is for the next timestamp!
	my @revs;
	for (my $r = 0; $r < @buffer - 1; $r++) {
	    my $rec = $buffer[$r];
	    if ($rec->[0] eq 'TextLife') {
		push @revs, [$rec->[3], $rec->[5]];
	    } elsif ($rec->[0] eq 'TextInc') {
		push @revs, [$rec->[3], $rec->[5]];
		push @revs, [$rec->[3], $rec->[9]];
	    } elsif ($rec->[0] eq 'EditLife') {
		push @revs, [$rec->[3], $rec->[5]];
	    } elsif ($rec->[0] eq 'EditInc') {
		push @revs, [$rec->[3], $rec->[5]];
		push @revs, [$rec->[3], $rec->[9]];
	    }
	}
	@revs = sort { $a->[1] <=> $b->[1] } @revs;
	foreach my $r (@revs) {
	    getRevNum(@$r);
	}
    }
    return shift @buffer;
}


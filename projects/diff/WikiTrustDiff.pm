package WikiTrustDiff;
use strict;
use warnings;

use Heap::Priority;
use Data::Dumper;

sub match_quality {
    my ($l, $i1, $l1, $i2, $l2) = @_;
    return $l;
}

# Create a hash table indexed by word, which gives the
# list of locations where the word appears in the input list.
sub make_index {
    my $words = shift @_;
    my $idx = {};
    for (my $i = 0; $i < @$words; $i++) { $idx->{ $words->[$i] } = []; }
    for (my $i = 0; $i < @$words; $i++) {
	push @{ $idx->{ $words->[$i] } }, $i;
    }
    return $idx;
}

sub build_heap {
    my $w1 = shift @_;
    my $w2 = shift @_;
    my $l1 = scalar(@$w1);
    my $l2 = scalar(@$w2);
    my $idx = make_index($w2);
    my $h = Heap::Priority->new();
    for (my $i1 = 0; $i1 < @$w1; $i1++) {
	# For every word in w1, find the list of matches in w2
	my $matches = $idx->{ $w1->[$i1] } || [];
	foreach my $i2 (@$matches) {
	    # for each match, compute how long the match is
	    my $k = 1;
	    while ($i1 + $k < $l1 && $i2 + $k < $l2
			&& ($w1->[$i1+$k] eq $w2->[$i2+$k]))
	    { $k++; }
	    my $q = match_quality($k, $i1, $l1, $i2, $l2);
	    $h->add([$k, $i1, $i2], $q);
	}
    }
    return $h;
}

sub find_unmatchedSeq {
    my ($i1, $i2, $len, $matched1, $matched2) = @_;
    my $start = 0;
    while ($start < $len &&
		($matched1->[$i1+$start] || $matched2->[$i2+$start]))
    { $start++; }
    my $end = $start+1;
    while ($end < $len &&
		!$matched1->[$i1+$start] && !$matched2->[$i2+$start])
    { $end++; }
    return undef if $start >= $len;
    return ($start, $end);
}

sub process_best_matches {
    my ($h, $w1, $w2, $matched1, $matched2) = @_;

    my @editScript;

    my $matchId = 0;
    while (my $m = $h->pop()) {
	$matchId++;
	my ($k, $i1, $i2) = @$m;
	# have any of these words already been matched?
	my $unmatched_start = 0;
	my $i = 0;
	while ($i < $k) {
	    while ($i < $k && !$matched1->[$i1+$i] && !$matched2->[$i2+$i]) {
		$i++;
	    }
	    my $match_len = $i - $unmatched_start;
	    if ($match_len > 0 && $match_len < $k) {
		# there was a previous match that already used
		# part of the current match.
		# Split this one into smaller matches.
		my $q = match_quality($match_len,
				$i1+$unmatched_start, length(@$w1),
				$i2+$unmatched_start, length(@$w2));
		$h->add([$match_len,
			$i1+$unmatched_start, $i2+$unmatched_start], $q);
	    }
	    while ($i < $k && ($matched1->[$i1+$i] || $matched2->[$i2+$i])) {
		$i++;
		$unmatched_start = $i;
	    }
	}
	if ($unmatched_start == 0) {
	    # there was no previous match that overlapped with this one.
	    for (my $i = 0; $i < $k; $i++) {
		$matched1->[$i1+$i] = $matchId;
		$matched2->[$i2+$i] = $matchId;
	    }
	    push @editScript, ['Mov', $i1, $i2, $k ];
	}
    }
    return \@editScript;
}

sub find_unmatched {
    my $matched = shift @_;
    my $l = shift @_;
    my $editScript = shift @_;
    my $mode = shift @_;

    my $unmatched_start = 0;
    my $i = 0;
    while ($i < $l) {
	while ($i < $l && !$matched->[$i]) { $i++; }
	my $match_len = $i - $unmatched_start;
warn "Possible unmatched: $match_len @ $unmatched_start -- ( $match_len < $l ?)\n";
	if ($match_len > 0 && $match_len < $l) {
	    push @$editScript, [$mode, $unmatched_start, $match_len ];
	}
	while ($i < $l && $matched->[$i]) {
	    $i++;
	    $unmatched_start = $i;
	}
warn "Now $i < $l?\n";
    }
    if ($unmatched_start == 0) {
	push @$editScript, [$mode, 0, $l];
    }
}

sub edit_diff {
    my $w1 = shift @_;
    my $w2 = shift @_;
    my $h = build_heap($w1, $w2);
    my (@matched1, @matched2);
    my $editScript = process_best_matches($h, $w1, $w2,
		\@matched1, \@matched2);
    find_unmatched(\@matched1, scalar(@$w1), $editScript, 'Del');
    find_unmatched(\@matched2, scalar(@$w2), $editScript, 'Ins');
    return $editScript;
}

1;

package WikiTrust::TextTracking;
use strict;
use warnings;

use constant ALLOW_MULTI_MATCH => 0;

use Exporter;
use WikiTrust::Tuple;
use Heap::Priority;
use List::Util qw(min);
use Data::Dumper qw(Dumper);
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(edit_diff);

sub match_quality {
  my ($chunk, $k, $i1, $l1, $i2, $l2) = @_;
  my $m1 = (2*$i1+$k)/2.0;
  my $m2 = (2*$i2+$k)/2.0;
  my $q = abs($m1/$l1 - $m2/$l2);
  return WikiTrust::Tuple->new(-$chunk, $k, -$q);
}

# Create a hash table indexed by word,
# which gives the list of locations where
# the word appears in the previous revisions.
sub make_index {
  my $prevrevs = shift @_;
  my $idx = {};
  for (my $chunk = 0; $chunk < @$prevrevs; $chunk++) {
    my $words = $prevrevs->[$chunk];
    for (my $i = 0; $i < @$words; $i++) {
      my $w = $words->[$i];
      $idx->{ $w } = [] if !exists $idx->{$w};
      push @{ $idx->{ $w } }, [$chunk, $i];
    }
  }
  return $idx;
}

sub build_heap {
  my ($w1, $prevrevs) = @_;
  my $l1 = scalar(@$w1);
  my $idx = make_index($prevrevs);
  my $h = Heap::Priority->new();
  $h->fifo();
  Heap::Priority::raise_error(2, $h);
  for (my $i1 = 0; $i1 < @$w1; $i1++) {
    # For every word in w1,
    # find the list of matches in w2
    my $matches = $idx->{ $w1->[$i1] } || [];
    foreach my $m (@$matches) {
      # for each match, compute how long the match is
      my $chunk = $m->[0];
      my $i2 = $m->[1];
      my $w2 = $prevrevs->[$chunk];
      my $l2 = scalar(@$w2);
      my $k = 1;
      while ($i1 + $k < $l1 && $i2 + $k < $l2
	  && ($w1->[$i1+$k] eq $w2->[$i2+$k]))
      { $k++; }
      my $q = match_quality($chunk, $k, $i1, $l1, $i2, $l2);
      $h->add([$chunk, $k, $i1, $i2], $q);
    }
  }
  return $h;
}

sub scan_and_test {
  my ($len, $test) = @_;
  return undef if $len <= 0;
  my $start = 0;
  while ($start < $len && $test->($start)) { $start++; }
  my $end = $start+1;
  while ($end < $len && !$test->($end)) { $end++; }
  return undef if $start >= $len;
  return ($start, $end);
}

sub process_best_matches {
  my ($h, $w1, $prevrevs, $matched1, $matched2) = @_;

  my @editScript;

  my $matchId = 0;
  while (my $m = $h->pop()) {
    $matchId++;
    my ($chunk, $k, $i1, $i2) = @$m;
    # have any of these words already been matched?
    my ($start, $end) = scan_and_test($k,
		    sub { $matched1->[$i1+$_[0]] });
    next if !defined $start;
    next if ($end - $start != $k);
    # the whole sequence is still unmatched
    push @editScript, ['Mov', $chunk, $i2, $i1, $k ];
    for (my $i = $start; $i < $end; $i++) {
      $matched1->[$i1+$i] = $matchId;
    }
  }
  return \@editScript;
}

sub cover_unmatched {
  my ($matched, $l, $editScript, $mode) = @_;

  my $i = 0;
  while (1) {
    my ($start, $end) = scan_and_test($l,
	sub { $matched->[$i+$_[0]] });
    last if !defined $start;
    push @$editScript,
	 [$mode, $i+$start, $end-$start];
    $i += $end;
    $l -= $end;
  }
}

sub edit_diff {
  my ($w1, $prevrevs) = @_;
  my $h = build_heap($w1, $prevrevs);
  my (@matched1, @matched2);
  my $editScript = process_best_matches($h, $w1, $prevrevs,
      \@matched1, \@matched2);
  cover_unmatched(\@matched1, scalar(@$w1),
      $editScript, 'Ins');
  return $editScript;
}

1;

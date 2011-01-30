package WikiTrust::FasterDiff;
# A faster diff, which assumes that longer
# matches are always prioritized before
# shorter matches.
use strict;
use warnings;

use constant DEBUG => 0;

use WikiTrust::Tuple;
use WikiTrust::BasicDiff;
our @ISA = qw(WikiTrust::BasicDiff);

# Given the source string we are trying to transform from,
# build the heap of matches to the destination string.
sub build_heap {
  my $this = shift @_;
  my $chunk = shift @_;
  my $src = shift @_;
  $src = $this->parse($src, @_) if !ref $src;
  my %matched;
  $this->compute_heap(0, $src,
    sub {
      my ($chunk, $i1, $i2) = @_;
      return $matched{$i1, $i2};
    },
    sub {
      my ($chunk, $i1, $l1, $i2, $l2, $k) = @_;
      # remember that $k is the length of the match
      $matched{$chunk,$i1+$k-1,$i2+$k-1} = 1;
    },
    sub {
      my ($chunk, $i1, $l1, $i2, $l2, $k) = @_;
      my $q = $this->{quality}->($chunk, $k, $i1, $l1, $i2, $l2);
      $this->{heap}->add(
	WikiTrust::Tuple->new($chunk, $k, $i1, $i2),
	$q);
    }
  );
}

# This is exactly the same as in the parent class,
# except for when a region has already been previously matched.
# In that case, we construct the residual matches and add them
# to the heap.  For this to work properly, we must have that
# the quality measure puts longer matches before shorter matches.
sub process_best_matches {
  my ($this, $multimatch, $w1, $matched1) = @_;

  my $l1 = @$w1;
  my $l2 = @{ $this->{dst} };

  my @editScript;

  while (my $m = $this->{heap}->pop()) {
    my ($chunk, $k, $i1, $i2) = @$m;
    # have any of these words already been matched?
    my ($start, $end) = $this->scan_and_test($k,
	sub { $matched1->[$i1+$_[0]]
	    ||  $this->{matched_dst}->[$i2+$_[0]] });
    next if !defined $start;	# whole thing is matched
    if ($end - $start == $k) {
      # the whole sequence is still unmatched
      push @editScript, WikiTrust::Tuple->new('Mov', $chunk, $i1, $i2, $k);
      # and mark it matched
      $this->{matchId}++;
      for (my $i = $start; $i < $end; $i++) {
	$matched1->[$i1+$i] = $this->{matchId}
	    if !$multimatch;
	$this->{matched_dst}->[$i2+$i] = $this->{matchId};
      }
    } else {
	# found an unmatched subregion, but it's
	# less than the size we were hoping for.
	# So we must add the smaller matches back
	# into the heap...  starting with the match
	# we just found.
	do {
	  my $newK = $end - $start;
	  my $q = $this->{quality}->($chunk, $newK, $i1, $l1, $i2, $l2);
	  warn "Split into $i1, $i2, $newK ==> $q\n" if DEBUG;
	  $this->{heap}->add(
	      WikiTrust::Tuple->new($chunk, $newK, $i1, $i2),
	      $q);
	  $i1 += $end;
	  $i2 += $end;
	  $k -= $end;
	  ($start, $end) = $this->scan_and_test($k,
	      sub { $matched1->[$i1+$_[0]]
	      ||  $this->{matched_dst}->[$i2+$_[0]] });
	} while (defined $start);
    }
  }
  return \@editScript;
}

1;

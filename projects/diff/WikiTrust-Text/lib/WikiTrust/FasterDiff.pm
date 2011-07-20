package WikiTrust::FasterDiff;
# A faster diff, which assumes that longer
# matches are always prioritized before
# shorter matches.
use strict;
use warnings;

use WikiTrust::Tuple;
use WikiTrust::BasicDiff;

# Setup our baseclass; this file only has overrides
our @ISA = qw(WikiTrust::BasicDiff);

# Given the source string we are trying to transform from,
# build the heap of matches to the destination string.
sub build_heap {
  my $this = shift @_;
  my $chunk = shift @_;
  my $src = shift @_;
  $src = $this->parse($src, @_) if !ref $src;
  my %matched;
  $this->compute_heap($chunk, $src,
    sub {
      my ($chunk, $i1, $i2, $prev_matches) = @_;
      # The 'prev match' optimization:
      # return (grep { $i1 - 1 == $_ } @$prev_matches) > 0;
      return $matched{$chunk, $i1, $i2};
    },
    sub {
      # If we want to keep small matches, then we
      # can mark the match right away.  For WikiTrust,
      # we don't want small matches, so this function
      # does nothing.
      # OLD CODE:
      # my ($chunk, $i1, $l1, $i2, $l2, $k) = @_;
      ## remember that $k is the length of the match
      # $matched{$chunk,$i1+$k-1,$i2+$k-1} = 1;
    },
    sub {
      my ($chunk, $i1, $l1, $i2, $l2, $k) = @_;
      # skip short matches
      return if $k < $this->{minMatch};

      # mark the positions as matched; not necessary for
      # the 'prev matches' optimization
      foreach my $i (0..$k-1) {
        $matched{$chunk, $i1+$i,$i2+$i} = 1;
      }

      my $qfunc = $this->{quality};
      my $q = $qfunc->($chunk, $k, $i1, $l1, $i2, $l2);
      $this->{heap}->insert($q,
	WikiTrust::Tuple->new($chunk, $k, $i1, $i2));
    }
  );
}

# This is exactly the same as in the parent class, except
# for when a region has already been previously matched.
# In that case, we construct the residual matches and add
# them to the heap.  For this to work properly, we must have
# that the quality measure puts longer matches before
# shorter matches.
sub process_best_matches {
  my ($this, $multimatch, $chunks, $chunkmatch) = @_;

  my $l2 = @{ $this->{dst} };

  my @editScript;

  while (my $m = $this->{heap}->pop()) {
    my ($chunk, $k, $i1, $i2) = @$m;
    my $w1 = $chunks->[$chunk];
    my $matched1 = $chunkmatch->[$chunk];
    my $l1 = @$w1;
    # have any of these words already been matched?
    my ($start, $end) = $this->scan_and_test($k,
	sub { $matched1->[$i1+$_[0]]
	    ||  $this->{matched_dst}->[$i2+$_[0]] });
    next if !defined $start;	# whole thing is matched
    if ($end - $start == $k) {
      # the whole sequence is still unmatched
      my $match = WikiTrust::Tuple->new(
	'Mov', $chunk, $i1, $i2, $k
      );
      push @editScript, $match;
      # and mark it matched
      for (my $i = $start; $i < $end; $i++) {
	$matched1->[$i1+$i] = $match
	    if !$multimatch;
	$this->{matched_dst}->[$i2+$i] = $match;
      }
    } else {
      # found an unmatched subregion, but it's
      # less than the size we were hoping for.
      # So we must add the smaller matches back
      # into the heap...  starting with the match
      # we just found.
      do {
	my $newK = $end - $start;
	# skip too-short matches
	if ($newK >= $this->{minMatch}) {
	  my $qfunc = $this->{quality};
	  my $q = $qfunc->($chunk, $newK, $i1+$start, $l1, $i2+$start, $l2);
	  $this->{heap}->insert($q, WikiTrust::Tuple->new(
	    $chunk, $newK, $i1+$start, $i2+$start
	  ));
	}
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

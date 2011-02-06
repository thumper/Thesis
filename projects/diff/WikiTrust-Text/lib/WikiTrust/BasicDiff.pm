package WikiTrust::BasicDiff;
use strict;
use warnings;

use constant FASTER => 1;

use WikiTrust::Tuple;
use WikiTrust::PriorityQ;
use List::Util qw(min);
use Carp;

our $VERSION = '0.01';

sub new {
  my $class = shift @_;
  my $this = bless {
    quality => \&match_quality,
    dst => [],
    minMatch => 3,
  }, $class;
  $this->init();
  return $this;
}

sub init {
  my $this = shift @_;
  $this->{heap} = WikiTrust::PriorityQ->new();
  $this->{matched_dst} = [];
  $this->{matchId} = 0;
}

sub set_minMatch {
    my $this = shift @_;
    $this->{minMatch} = shift @_;
}

# Parse a string into a list of words.
# For this demo, we only split on whitespace,
# but the full Ocaml version interprets wiki
# markup to better distinguish "words".
sub parse {
  my ($this, $str) = @_;
  confess "No string defined" if !defined $str;
  my @words = split(/\s+/, $str);
  return \@words;
}

# Set the destination string that we are
# trying to transform into.
sub target {
  my $this = shift @_;
  my $str = shift @_;
  $str = $this->parse($str, @_) if !ref $str;
  $this->{dst} = $str;
  return $this->{dst};
}


sub match_quality {
  my ($chunk, $k, $i1, $l1, $i2, $l2) = @_;
  my $pos1 = (2*$i1 + $k) / $l1;
  my $pos2 = (2*$i2 + $k) / $l2;
  # the closer to zero, the better
  my $q = abs($pos1 - $pos2);
  # The Heap::Priority module works much faster
  # if we use floats instead of tuples to sort
  # the entries...
  return (-$chunk*10000) + $k - $q if FASTER;
  return WikiTrust::Tuple->new(-$chunk, $k, -$q);
}

# Create a hash table indexed by word,
# which gives the list of locations where
# the word appears in the input list.
sub make_index {
  my ($this, $words) = @_;
  my $idx = {};
  for (my $i = 0; $i < @$words; $i++) {
    my $w = $words->[$i];
    $idx->{$w} = [] if !exists $idx->{$w};
    push @{ $idx->{$w} }, $i;
  }
  return $idx;
}

sub compute_heap {
  my ($this, $chunk, $w1,
    $skipmatch, $eachk, $maxk) = @_;
  my $w2 = $this->{dst};
  my $l1 = scalar(@$w1);
  my $l2 = scalar(@$w2);
  my $idx = $this->make_index($w1);
  for (my $i2 = 0; $i2 < @$w2; $i2++) {
    # For every unmatched word in w2,
    # find the list of matches in w1
    next if $this->{matched_dst}->[$i2];
    my $matches = $idx->{ $w2->[$i2] } || [];
    foreach my $i1 (@$matches) {
      # Do we want to skip this match for some reason?
      next if $skipmatch->($chunk, $i1, $i2);
      # for each match, compute all the longer strings
      # that match starting at this point.
      # Note that we already know $k == 0 is a match
      my $k = 0;
      do {
	# for each partial match, call $eachk
	$eachk->($chunk, $i1, $l1, $i2, $l2, $k+1);
	$k++;
      } while ($i1 + $k < $l1 && $i2 + $k < $l2
	  && ($w1->[$i1+$k] eq $w2->[$i2+$k]));
      # And finally, call $maxk for the maximal match.
      # Note that $eachk will also have been called for
      # this same length of match.
      $maxk->($chunk, $i1, $l1, $i2, $l2, $k);
    }
  }
}

# Given the source string we are trying to transform from,
# build the heap of matches to the destination string.
sub build_heap {
  my ($this, $chunk, $src) = @_;
  $src = $this->parse($src, @_) if !ref $src;
  $this->compute_heap($chunk, $src,
    sub { return 0; },    # never skip match
    sub {
      my ($chunk, $i1, $l1, $i2, $l2, $k) = @_;
      return if $k < $this->{minMatch};
      my $q = $this->{quality}->($chunk, $k,
	$i1, $l1, $i2, $l2);
      $this->{heap}->insert($q,
	WikiTrust::Tuple->new($chunk, $k, $i1, $i2));
    },
    sub { }
  );
}
# return a region of [start,end) which
# has $test->() false for the whole interval
sub scan_and_test {
  my ($this, $len, $test) = @_;
  return undef if $len <= 0;
  my $start = 0;
  while ($start < $len && $test->($start)) { $start++; }
  return undef if $start >= $len;
  my $end = $start+1;
  while ($end < $len && !$test->($end)) { $end++; }
  return ($start, $end);
}

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
      push @editScript, WikiTrust::Tuple->new('Mov', $chunk, $i1, $i2, $k);
      # and mark it matched
      $this->{matchId}++;
      for (my $i = $start; $i < $end; $i++) {
	$matched1->[$i1+$i] = $this->{matchId}
	    if !$multimatch;
	$this->{matched_dst}->[$i2+$i] = $this->{matchId};
      }
    }
  }
  return \@editScript;
}

sub cover_unmatched {
  my ($this, $matched, $l, $editScript, $mode) = @_;

  my $i = 0;
  while (1) {
    my ($start, $end) = $this->scan_and_test($l,
	sub { $matched->[$i+$_[0]] });
    last if !defined $start;
    push @$editScript,
      WikiTrust::Tuple->new($mode, $i+$start, $end-$start);
    $i += $end;
    $l -= $end;
  }
}


# Compute the edit script to transform src into dst.
sub edit_diff {
  my $this = shift @_;
  my $src = shift @_;
  $src = $this->parse($src, @_) if !ref $src;

  $this->init();
  $this->build_heap(0, $src);
  my $matched_chunks = [ [] ];
  my $editScript = $this->process_best_matches(0, [$src],
      $matched_chunks);
  $this->cover_unmatched($matched_chunks->[0],
      scalar(@$src), $editScript, 'Del');
  $this->cover_unmatched($this->{matched_dst},
      scalar(@{ $this->{dst} }),
      $editScript, 'Ins');
  return $editScript;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WikiTrust::Diff - Perl extension for text differencing

=head1 SYNOPSIS

  use WikiTrust::BasicDiff;
  my $diff = WikiTrust::BasicDiff->new();
  $diff->target("The final string.");
  my $src = "The initial string.";
  my $script = $diff->edit_diff($src);

=head1 DESCRIPTION

A module to demonstrate the basic differencing algorithm
used in the WikiTrust project.

=head1 SEE ALSO

B<WikiTrust::FasterDiff>, B<WikiTrust::TextTracking>

=head1 AUTHOR

Bo Adler, E<lt>thumper@alumni.caltech.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bo Adler

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

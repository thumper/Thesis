package WikiTrust::BasicDiff;
use strict;
use warnings;

use constant DEBUG => 0;

use WikiTrust::Tuple;
use Heap::Priority;
use List::Util qw(min);
use Carp;

our $VERSION = '0.01';

sub new {
  my $class = shift @_;
  my $this = bless {
    quality => \&match_quality,
    dst => [],
  }, $class;
  $this->init();
  return $this;
}

sub init {
  my $this = shift @_;
  $this->{heap} = Heap::Priority->new();
  $this->{matched_dst} = [];
  $this->{matchId} = 0;
}

sub parse {
  my ($this, $str) = @_;
  confess "No string defined" if !defined $str;
  my @words = split(/\s+/, $str);
  return \@words;
}

sub target {
  my ($this, $str) = @_;
  if (ref $str) {
    $this->{dst} = $str;
  } else {
    $this->{dst} = $this->parse($str);
  }
  return $this->{dst};
}

sub match_quality {
  my ($chunk, $k, $i1, $l1, $i2, $l2) = @_;
  my $q = $k / min($l2, $l1) - 0.3
    * abs(($i1/$l1) - ($i2/$l2));
warn "Mov $i1, $i2, $k ($l1, $l2) ==> $q\n" if DEBUG;
  return WikiTrust::Tuple->new(-$chunk, $k, $q);
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
  my ($this, $chunk, $w1) = @_;
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
      # for each match, compute all the longer strings
      # that match starting at this point.
      # Note that we already know $k == 0 is a match
      my $k = 0;
      do {
	my $q = $this->{quality}->($chunk, $k+1, $i1, $l1, $i2, $l2);
	$this->{heap}->add(
	    WikiTrust::Tuple->new($chunk, $k+1, $i1, $i2),
	    $q);
	$k++;
      } while ($i1 + $k < $l1 && $i2 + $k < $l2
	  && ($w1->[$i1+$k] eq $w2->[$i2+$k]));
    }
  }
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
  my ($this, $multimatch, $w1, $matched1) = @_;

  my @editScript;

  while (my $m = $this->{heap}->pop()) {
    $this->{matchId}++;
    my ($chunk, $k, $i1, $i2) = @$m;
    # have any of these words already been matched?
    while (1) {
      my ($start, $end) = $this->scan_and_test($k,
	  sub { $matched1->[$i1+$_[0]]
	    ||  $this->{matched_dst}->[$i2+$_[0]] });
      last if !defined $start;
      if ($end - $start == $k) {
	# the whole sequence is still unmatched
	push @editScript, WikiTrust::Tuple->new('Mov', $chunk, $i1, $i2, $k);
	for (my $i = $start; $i < $end; $i++) {
	  $matched1->[$i1+$i] = $this->{matchId}
	    if !$multimatch;
	  $this->{matched_dst}->[$i2+$i] = $this->{matchId};
	}
      }
      $i1 += $end;
      $i2 += $end;
      $k -= $end;
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
  my ($this, $src) = @_;
  $this->init();
  $this->compute_heap(0, $src);
  my (@matched1);
  my $editScript = $this->process_best_matches(0, $src, \@matched1);
  $this->cover_unmatched(\@matched1, scalar(@$src),
      $editScript, 'Del');
  $this->cover_unmatched($this->{matched_dst}, scalar(@{ $this->{dst} }),
      $editScript, 'Ins');
  return $editScript;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WikiTrust::Diff - Perl extension for text differencing

=head1 SYNOPSIS

  use WikiTrust::Diff;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for WikiTrust-Text, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Bo Adler, E<lt>thumper@alumni.caltech.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bo Adler

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

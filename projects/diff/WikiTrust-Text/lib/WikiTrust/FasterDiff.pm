package WikiTrust::FasterDiff;
use strict;
use warnings;

use WikiTrust::BasicDiff;

our @ISA = qw(WikiTrust::BasicDiff);


use WikiTrust::Tuple;
use List::Util qw(min);

sub init {
    my $this = shift @_;
    $this->SUPER::init();
    $this->{quality} = \&match_quality;
}

sub match_quality {
  my ($chunk, $k, $i1, $l1, $i2, $l2) = @_;
  my $q = $k / min($l2, $l1) - 0.3
    * abs(($i1/$l1) - ($i2/$l2));
warn "Mov $i1, $i2, $k ($l1, $l2) ==> $q\n";
  return (-$chunk*10000) + $k + $q;
}

sub compute_heap {
  my ($this, $chunk, $w1) = @_;
  my $w2 = $this->{dst};
  my $l1 = scalar(@$w1);
  my $l2 = scalar(@$w2);
  my $idx = $this->make_index($w1);
  my %matched;
  for (my $i2 = 0; $i2 < @$w2; $i2++) {
    # For every unmatched word in w2,
    # find the list of matches in w1
    next if $this->{matched_dst}->[$i2];
    my $matches = $idx->{ $w2->[$i2] } || [];
    foreach my $i1 (@$matches) {
      # Was this position already part of an earlier match?
      # If so, then there's already a longer match in the system.
      next if $matched{$i1,$i2};
      # for each match, compute the longest string
      # starting at this point.
      # Note that we already know $k == 0 is a match
      my $k = 0;
      do {
        $matched{$i1+$k,$i2+$k} = 1;
	$k++;
      } while ($i1 + $k < $l1 && $i2 + $k < $l2
	  && ($w1->[$i1+$k] eq $w2->[$i2+$k]));
      # $k is now the length of the match
      my $q = $this->{quality}->($chunk, $k, $i1, $l1, $i2, $l2);
warn "Adding $i1, $i2, $k ==> $q\n";
      $this->{heap}->add(
	  WikiTrust::Tuple->new($chunk, $k, $i1, $i2),
	  $q);
    }
  }
}

sub process_best_matches {
  my ($this, $w1, $matched1) = @_;

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
      push @editScript, WikiTrust::Tuple->new('Mov', $i1, $i2, $k);
      # and mark it matched
      $this->{matchId}++;
      for (my $i = $start; $i < $end; $i++) {
	$matched1->[$i1+$i] = $this->{matchId};	# TODO: multimatch?
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
warn "Split into $i1, $i2, $newK ==> $q\n";
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

# Compute the edit script to transform src into dst.
sub edit_diff {
  my ($this, $src) = @_;
  $this->init();
  $this->compute_heap(0, $src);
  my (@matched1);
  my $editScript = $this->process_best_matches($src, \@matched1);
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

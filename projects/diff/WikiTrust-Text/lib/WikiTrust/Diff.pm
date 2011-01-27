package WikiTrust::Diff;
use strict;
use warnings;

our $VERSION = '0.01';

use constant ALLOW_MULTI_MATCH => 0;

use WikiTrust::Tuple;
use Heap::Priority;
use List::Util qw(min);

sub match_quality {
  my ($k, $i1, $l1, $i2, $l2) = @_;
  my $q = $k / min($l2, $l1) - 0.3
    * abs(($i1/$l1) - ($i2/$l2));
  return WikiTrust::Tuple->new($k, $q);
}

# Create a hash table indexed by word,
# which gives the list of locations where
# the word appears in the input list.
sub make_index {
  my $words = shift @_;
  my $idx = {};
  for (my $i = 0; $i < @$words; $i++) {
    $idx->{ $words->[$i] } = [];
  }
  for (my $i = 0; $i < @$words; $i++) {
    push @{ $idx->{ $words->[$i] } }, $i;
  }
  return $idx;
}

sub build_heap {
  my ($w1, $w2) = @_;
  my $l1 = scalar(@$w1);
  my $l2 = scalar(@$w2);
  my $idx = make_index($w2);
  my $h = Heap::Priority->new();
  for (my $i1 = 0; $i1 < @$w1; $i1++) {
    # For every word in w1,
    # find the list of matches in w2
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
  my ($h, $w1, $w2, $matched1, $matched2) = @_;

  my @editScript;

  my $matchId = 0;
  while (my $m = $h->pop()) {
    $matchId++;
    my ($k, $i1, $i2) = @$m;
    # have any of these words already been matched?
    while (1) {
      my ($start, $end) = scan_and_test($k,
	  sub { $matched1->[$i1+$_[0]]
	  ||  $matched2->[$i2+$_[0]] });
      last if !defined $start;
      if ($end - $start == $k) {
	# the whole sequence is still unmatched
	push @editScript, WikiTrust::Tuple->new('Mov', $i1, $i2, $k);
	for (my $i = $start; $i < $end; $i++) {
	  $matched1->[$i1+$i] = $matchId
	    if !ALLOW_MULTI_MATCH;
	  $matched2->[$i2+$i] = $matchId;
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
  my ($matched, $l, $editScript, $mode) = @_;

  my $i = 0;
  while (1) {
    my ($start, $end) = scan_and_test($l,
	sub { $matched->[$i+$_[0]] });
    last if !defined $start;
    push @$editScript,
	 WikiTrust::Tuple->new($mode, $i+$start, $end-$start);
    $i += $end;
    $l -= $end;
  }
}

# Compute the edit script to transform $w1 into $w2
sub edit_diff {
  my ($w1, $w2) = @_;
  my $h = build_heap($w1, $w2);
  my (@matched1, @matched2);
  my $editScript = process_best_matches($h, $w1, $w2,
      \@matched1, \@matched2);
  cover_unmatched(\@matched1, scalar(@$w1),
      $editScript, 'Del');
  cover_unmatched(\@matched2, scalar(@$w2),
      $editScript, 'Ins');
  return $editScript;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

WikiTrust::Diff - Perl extension for text differencing

=head1 SYNOPSIS

  use WikiTrust-Text;
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

Bo Adler, E<lt>thumper17@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Bo Adler

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut

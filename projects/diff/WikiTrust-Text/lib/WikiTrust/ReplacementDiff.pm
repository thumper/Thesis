package WikiTrust::ReplacementDiff;
# A faster diff, which assumes that longer
# matches are always prioritized before
# shorter matches.
use strict;
use warnings;

use constant DEBUG => 0;

use WikiTrust::Tuple;
use WikiTrust::FasterDiff;

# Setup our baseclass; this file only has overrides
our @ISA = qw(WikiTrust::FasterDiff);

# Look for unmatched blocks that could be replacements
sub replacement_scan {
  my ($this, $editScript, $matched, $l, $chunks) = @_;

  my $i = 0;
  while (1) {
    my ($start, $end) = $this->scan_and_test($l,
	sub { $matched->[$i+$_[0]] });
    last if !defined $start;
    # Found an unmatched section.
    # Find the 'before' block
    my $before = undef;
    $before = $matched->[$i+$start-1]
	if $i+$start > 0;
    # And the 'after' block
    my $after = undef;
    $after = $matched->[$i+$end]
	if $end < $l;

    # pre-advance to next block to next block
    my $rep_start = $i+$start;
    my $rep_end = $i+$end;
    my $rep_len = $end - $start;
    $i += $end;
    $l -= $end;
    # now check to see if the before/after chunks
    # indicate that there might be a replacement

    # bookends in different chunks?
    next if (defined $before && defined $after && $before->[1] != $after->[1]);

    # calculate all the parameter
    my $src_chunk = 0;
    $src_chunk = $before->[1] if defined $before;
    $src_chunk = $after->[1] if defined $after;
    my $src_start = 0;
    $src_start = $before->[2]+$before->[4] if defined $before;
    my $src_end = scalar(@{ $chunks->[$src_chunk] });
    $src_end = $after->[2] if defined $after;

    # not a replacement if the size is zero
    next if $src_end - $src_start == 0;

    # check for any matches in between.
    # If so, it's not a replacement.
    my $found = 0;
    for (my $i = $src_start; $i < $src_end; $i++) {
      if ($chunks->[$src_chunk]->[$i]) {
	$i = $src_end;
	$found = 1;
      }
    }
    next if $found;

    # Well, it sure looks like a replacement!
    # Mark the pieces as matched
    my $match = WikiTrust::Tuple->new('Rep', $src_chunk,
	$src_start, $src_end-$src_start,
        $rep_start, $rep_len);
    push @$editScript, $match;
    for (my $i = $src_start; $i < $src_end; $i++) {
      $chunks->[$src_chunk]->[$i] = $match;
    }
    for (my $i = $rep_start; $i < $rep_end; $i++) {
      $matched->[$i] = $match;
    }
  }

}

1;

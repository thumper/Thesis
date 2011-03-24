package WikiTrust::ReplacementDiff;
# After locating all the Mov operations,
# scan the unmatched sections and see if any
# are bracketed by Mov operations.  If the Mov
# operations come from the same chunk and
# there is text in the middle, then this is
# probably a substitution

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
    # Get the next unmatched chunk in the target
    my ($start, $end) = $this->scan_and_test($l,
	sub { $matched->[$i+$_[0]] });
    last if !defined $start;
    # Found an unmatched section.
    # Find the Mov operation that comes 'before' this section.
    # If we are at the start of the string, then keep as undef.
    my $before = undef;
    $before = $matched->[$i+$start-1]
	if $i+$start > 0;
    # And find the Mov operation that is after the unmatched section.
    # (undef == at the end of the string.)
    my $after = undef;
    $after = $matched->[$i+$end]
	if $end < $l;

    # Keep the parameters of this potential replacement...
    my $rep_start = $i+$start;
    my $rep_end = $i+$end;
    my $rep_len = $end - $start;
    # and update ($i, $l) for the next scan_and_match call.
    $i += $end;
    $l -= $end;

    # now check to see if the before/after chunks
    # indicate that there might be a replacement

    # bookends in different chunks?
    next if (defined $before && defined $after && $before->[1] != $after->[1]);

    # calculate all the parameters
    my $src_chunk = 0;
    $src_chunk = $before->[1] if defined $before;
    $src_chunk = $after->[1] if defined $after;
    my $src_start = 0;
    $src_start = $before->[2]+$before->[4] if defined $before;
    my $src_end = scalar(@{ $chunks->[$src_chunk] });
    $src_end = $after->[2] if defined $after;

    # not a replacement if the size is zero,
    # which indicates that there was no actual string in the src.
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
    # Note that we can replace a piece of text with a new
    # piece that is of a different length.

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

package WikiTrust::FasterTextTracking;
# Assume that more recent chunks are always
# preferred by the quality function.
use strict;
use warnings;

use WikiTrust::BasicTextTracking;

our @ISA = qw(WikiTrust::BasicTextTracking);

# Compute the edit script to transform src into dst.  But we
# only care about mov operations, so don't compute the INS
# and DEL operations.
sub edit_diff {
  my ($this, $chunk, $src) = @_;
  # Don't call $this->init() because we want to maintain the
  # matched_dst data, which is tracking which words have
  # already been matched in the target string.  The heap
  # itself will already be empty, because
  # $this->process_best_matches() always deals with the
  # entire heap.
  $this->build_heap($chunk, $src);
  my $editScript = $this->process_best_matches(
    1, $src, []
  );
  return $editScript;
}

sub track_text {
  my ($this, $prevrevs) = @_;

  $this->init();
  # Since we prefer chunks with more liveness, we do
  # matches in a serial fashion
  for (my $chunk = 0; $chunk < @$prevrevs; $chunk++) {
    my $src = $prevrevs->[$chunk];
    my $script = $this->edit_diff($chunk, $src);
    $this->fix_author($script, $prevrevs);
  }
  return $this->{dst};
}


1;

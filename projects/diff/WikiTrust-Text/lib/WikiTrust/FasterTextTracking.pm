package WikiTrust::FasterTextTracking;
# Assume that more recent chunks are always
# preferred by the quality function.
use strict;
use warnings;

use WikiTrust::BasicTextTracking;

our @ISA = qw(WikiTrust::BasicTextTracking);

# Compute the edit script to transform src into dst.
# But we only care about mov operations
sub edit_diff {
  my ($this, $chunk, $src) = @_;
  # do not initialize the heap!
  $this->build_heap($chunk, $src);
  my $editScript = $this->process_best_matches(1, $src, []);
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

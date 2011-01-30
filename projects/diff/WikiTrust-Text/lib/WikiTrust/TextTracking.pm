package WikiTrust::TextTracking;
use strict;
use warnings;

use constant DEBUG => 0;

use WikiTrust::FasterDiff;
use WikiTrust::Word;
use Carp;

our @ISA = qw(WikiTrust::FasterDiff);

# When we parse a string into words, we actually want
# to tag each word with a revid.  Later, we will assign
# proper revids to each word.
sub parse {
  my ($this, $str, $revid) = @_;
  my $words = $this->SUPER::parse($str);
  my @words = map { WikiTrust::Word->new($_, $revid) } @$words;
  return \@words;
}

# Compute the edit script to transform src into dst.
# But we only care about mov operations
sub edit_diff {
  my ($this, $chunk, $src) = @_;
  $this->build_heap($chunk, $src);
  my (@matched1);
  my $editScript = $this->process_best_matches(1, $src, \@matched1);
  return $editScript;
}

sub fix_author {
  my ($this, $script, $src) = @_;
  foreach my $match (@$script) {
    my $mode = shift @$match;
    confess "Bad mode: $mode" if $mode ne 'Mov';
    my ($chunk, $i1, $i2, $len) = @$match;
    for (my $i = 0; $i < $len; $i++) {
      $this->{dst}->[$i2+$i]->[1] =
	$src->[$i1+$i]->[1];
    }
  }
}

sub track_text {
  my ($this, $prevrevs) = @_;

  $this->init();
  # Since we prefer chunks with more liveness, we do
  # matches in a serial fashion
  for (my $chunk = 0; $chunk < @$prevrevs; $chunk++) {
    my $src = $prevrevs->[$chunk];
    my $script = $this->edit_diff($chunk, $src);
    $this->fix_author($script, $src);
  }
  return $this->{dst};
}


1;

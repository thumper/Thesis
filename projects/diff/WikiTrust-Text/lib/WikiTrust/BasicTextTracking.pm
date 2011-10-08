package WikiTrust::BasicTextTracking;
use strict;
use warnings;

use constant DEBUG => 0;

use WikiTrust::FasterDiff;
use WikiTrust::Word;
use Carp;

our @ISA = qw(WikiTrust::FasterDiff);

sub new {
  my $class = shift @_;
  my $self = WikiTrust::FasterDiff->new(@_);
  $self->{minMatch} = 3;
  bless $self, $class;
}

# When we parse a string into words, we actually want
# to tag each word with a revid.  Later, we will assign
# proper revids to each word.
sub parse {
  my ($this, $str, $revid) = @_;
  my $words = $this->SUPER::parse($str);
  my @words = map { WikiTrust::Word->new($_, $revid) }
    @$words;
  return \@words;
}

sub fix_author {
  my ($this, $script, $prevrevs) = @_;
  foreach my $match (@$script) {
    my $mode = shift @$match;
    confess "Bad mode: $mode" if $mode ne 'Mov';
    my ($chunk, $i1, $i2, $len) = @$match;
    # reject small matches
    ## code: next if $len < $this->{minMatch};
    for (my $i = 0; $i < $len; $i++) {
      $this->{dst}->[$i2+$i]->[1] =
	$prevrevs->[$chunk]->[$i1+$i]->[1];
    }
  }
}

sub track_text {
  my ($this, $prevrevs) = @_;

  $this->init();
  my $chunk_matches = [];
  # Instead of matching against a single previous rev,
  # we need to build a heap of matching chunks for
  # all the previous revs.
  for (my $chunk = 0; $chunk < @$prevrevs; $chunk++) {
    $chunk_matches->[$chunk] = [];
    my $src = $prevrevs->[$chunk];
    $this->build_heap($chunk, $src);
  }
  # And then find the best matches

  my $editScript = $this->process_best_matches(1,
    $prevrevs, $chunk_matches);
  # And copy the proper authors from the prev revs
  $this->fix_author($editScript, $prevrevs);

  return $this->{dst};
}


1;

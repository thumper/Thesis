package WikiTrust::TextTracking;
use strict;
use warnings;

use constant DEBUG => 0;

use WikiTrust::FasterDiff;
use WikiTrust::Word;
use Carp;

our @ISA = qw(WikiTrust::FasterDiff);

sub parse {
  my ($this, $str, $revid) = @_;
  my $words = $this->SUPER::parse($str);
  my @words = map { WikiTrust::Word->new($_, $revid) } @$words;
  return \@words;
}

sub target {
  my ($this, $str, $revid) = @_;
  if (ref $str) {
    $this->{dst} = $str;
  } else {
    $this->{dst} = $this->parse($str, $revid);
  }
  return $this->{dst};
}

# Compute the edit script to transform src into dst.
# But we only care about mov operations
sub edit_diff {
  my ($this, $chunk, $src) = @_;
  $this->compute_heap($chunk, $src);
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

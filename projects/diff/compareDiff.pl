#!/usr/bin/perl

use strict;
use warnings;

use lib './WikiTrust-Text/lib';
use XML::Simple;
use WikiTrust::BasicDiff;
use WikiTrust::FasterDiff;
use Benchmark qw(:all);
use Data::Dumper;

my $xs = XML::Simple->new(ForceArray => 1);
my $ref = $xs->XMLin(shift @ARGV);

my $prevrevs = [];
my $prevrevids = [];
foreach my $page (@{ $ref->{page} }) {
  for (my $i = 0; $i < @{ $page->{revision} }; $i++) {
    my ($next, $rev, $author, $revid) = getRevInfo($page, $i);
    next if $next;
    my $text = $rev->{text}->[0]->{content};

    my $d1 = WikiTrust::BasicDiff->new();
    my $d2 = WikiTrust::FasterDiff->new();
    my $words = $d1->target($text);
    $d2->target($words);

    my $prevwords = $prevrevs->[0];
    if (defined $prevwords) {
      my ($s1, $s2);
      timethis(1, sub { $s2 = $d2->edit_diff($prevwords); }, "FasterDiff");
      timethis(1, sub { $s1 = $d1->edit_diff($prevwords); }, "BasicDiff");
      if (compareScripts($s1, $s2)) {
	print "revid $revid  :: SAME\n";
      } else {
	print "revid $revid  :: DIFFERENT\n";
	print "BasicDiff: ", Dumper($s1), "\n";
	print "FasterDiff: ", Dumper($s2), "\n";
      }
    }

    unshift @$prevrevs, $words;
    unshift @$prevrevids, $revid;
    if (@$prevrevids > 10) {
	pop @$prevrevs;
	pop @$prevrevids;
    }
  }
}

sub compareScripts {
  my ($revid, $s1, $s2) = @_;

  return 0 if (@$s1 != @$s2);
  for (my $i = 0; $i < @$s1; $i++) {
    return 0 if $s1->[$i] != $s2->[$i];
  }
  return 1;
}

sub getAuthor {
  my $rev = shift @_;
  my $author = $rev->{contributor}->[0]->{username}->[0];
  $author = $rev->{contributor}->[0]->{ip}->[0] if !defined $author;
  return $author;
}

sub getRevInfo {
  my ($page, $i) = @_;
  my $rev = $page->{revision}->[$i];
  my $author = getAuthor($rev);
  my $revid = $rev->{id}->[0];
  warn "Working on author $author @ $revid\n";
  my $next = 0;
  if ($i+1 < @{ $page->{revision} }) {
    # Don't work on version if the next one is
    # by the same author
    my $nextrev = $page->{revision}->[$i+1];
    my $nextauthor = getAuthor($nextrev);
    $next = 1 if $author eq $nextauthor;
  }
  return ($next, $rev, $author, $revid);
}

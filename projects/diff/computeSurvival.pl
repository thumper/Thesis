#!/usr/bin/perl

use strict;
use warnings;

use lib './WikiTrust-Text/lib';
use XML::Simple;
use WikiTrust::FasterTextTracking;
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
    my $text = $rev->{text}->[0]->{content} || '';

    my $tt = WikiTrust::FasterTextTracking->new();
    my $words = $tt->target($text, $revid);

    timethis(1, sub { $words = $tt->track_text($prevrevs); },
	"FasterTextTracking");
    my (%author);
    foreach my $w (@$words) {
	$author{$w->[1]}++;
    }
    print "====== revid $revid\n";
    foreach my $a (keys %author) {
	print "$a\t$author{$a}\n";
    }

    unshift @$prevrevs, $words;
    unshift @$prevrevids, $revid;
    if (@$prevrevids > 10) {
	pop @$prevrevs;
	pop @$prevrevids;
    }
  }
}
exit(0);

sub compareResults {
  my ($s1, $s2) = @_;

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
  if (!defined $revid) {
    warn "No revid for this revision?";
    delete $rev->{text};
    die Dumper($rev);
  }
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

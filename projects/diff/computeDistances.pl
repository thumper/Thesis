#!/usr/bin/perl

use strict;
use warnings;

use lib './WikiTrust-Text/lib';
use XML::Simple;
use WikiTrust::FasterTextTracking;
use Benchmark qw(:all);
use Data::Dumper;
use Switch;

use constant SCALE => 18.0;

my $xs = XML::Simple->new(ForceArray => 1);
my $ref = $xs->XMLin(shift @ARGV);

print "graph EditDistances {\n";
my $count = 0;

my $prevrevs = [];
my $prevrevids = [];
foreach my $page (@{ $ref->{page} }) {
  for (my $i = 0; $i < @{ $page->{revision} }; $i++) {
    my ($next, $rev, $author, $revid) = getRevInfo($page, $i);
    next if $next;
    my $text = $rev->{text}->[0]->{content} || '';

    
    my $diff = WikiTrust::FasterDiff->new();
    my $words = $diff->target($text);

    doDiff($revid, $diff, $prevrevs, $prevrevids, 1, 1.0);
    doDiff($revid, $diff, $prevrevs, $prevrevids, 2, 0.5);
    #doDiff($revid, $diff, $prevrevs, $prevrevids, 3, 0.8);
    #doDiff($revid, $diff, $prevrevs, $prevrevids, 5, 0.3);
    #doDiff($revid, $diff, $prevrevs, $prevrevids, 10, 0.2);
    #doDiff($revid, $diff, $prevrevs, $prevrevids, 15, 0.1);

    push @$prevrevs, $words;
    push @$prevrevids, $revid;
    if (@$prevrevids > 15) {
	shift @$prevrevs;
	shift @$prevrevids;
    }
    last if $count++ > 15;
  }
}
print "}\n";
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

sub doDiff {
    my ($revid, $diff, $prevrevs, $prevrevids, $numback, $weight) = @_;

    if ($weight == 1.0) {
	print "r$revid [label=\"\",shape=circle,height=0.001,width=0.001];\n";
    }

    return if @$prevrevs < $numback;
    my $editScript = $diff->edit_diff($prevrevs->[-$numback]);

    my $d = editDistance($editScript) / SCALE;
    $d = 0.0001 if $d == 0.0;
warn "$revid\tback=$numback\tdist=$d\n";
    my $prev_revid = $prevrevids->[-$numback];
    my $style = '';
    $style = ',style=invis' if $weight != 1.0;
    print "r$revid -- r$prev_revid [len=$d,weight=$weight$style];\n";
}


sub editDistance {
  my $s = shift @_;
  my $dist = 0;
  foreach my $m (@$s) {
    switch ($m->[0]) {
      case "Ins" { $dist += $m->[2]; }
      case "Del" { $dist += $m->[2]; }
      case "Mov" { ; }
      case "Rep" { $dist += $m->[5]; }
      else { die "Bad script: ".$m->[0]; }
    };
  }
  return $dist;
}

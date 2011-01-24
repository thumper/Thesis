#!/usr/bin/perl

use strict;
use warnings;

use lib '.';
use XML::Simple;
use WikiTrust::TextTracking;
use WikiTrust::Word;
use Data::Dumper qw(Dumper);

my $xs = XML::Simple->new(ForceArray => 1);
my $ref = $xs->XMLin(shift @ARGV);

my $prevrevs = [];
my $prevrevids = [];
foreach my $page (@{ $ref->{page} }) {
  foreach my $rev (@{ $page->{revision} }) {
    my $revid = $rev->{id}->[0];
    my $text = $rev->{text}->[0]->{content};
    my @words = map { WikiTrust::Word->new($_, $revid) }
	(split(/\s+/, $text));
    my $diff = edit_diff(\@words, $prevrevs);
    # Go back and fix the author of each word, based on
    # the edit script
#print Dumper($diff);
    foreach my $match (@$diff) {
      my $mode = shift @$match;
      if ($mode eq 'Ins') {
	my ($start, $len) = @$match;
	# by default, we already have the revid set
	# to the current rev
      } elsif ($mode eq 'Mov') {
	my ($chunk, $i1, $i2, $len) = @$match;
	for (my $i = 0; $i < $len; $i++) {
	  $words[$i2+$i]->[1] = $prevrevs->[$chunk]->[$i1+$i]->[1];
	}
      } else {
	die "Unknown diff cmd '$mode'";
      }
    }
#########
print "======\n";
my %count;
foreach my $w (@words) {
    $count{$w->[1]}++;
}
foreach my $r (sort keys %count) {
    print "$r\t$count{$r}\n";
}
print "*******\n";
foreach my $w (@words) {
  print $w->[1], "  ", $w->[0], "\n";
}
#########
    unshift @$prevrevs, \@words;
    unshift @$prevrevids, $revid;
    if (@$prevrevids > 10) {
	pop @$prevrevs;
	pop @$prevrevids;
    }
  }
}


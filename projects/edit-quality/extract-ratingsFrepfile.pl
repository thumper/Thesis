#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use List::Util qw( min max );
use lib 'lib';
use PAN;
use MediawikiDump;

my ($revids, $repFile) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 2], sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
});

open(my $editlong, ">perf-editlong.txt") || die "open: $!";
open(my $textlong, ">perf-textlong.txt") || die "open: $!";

open(my $fh, "<", $repFile) || die "open($repFile): $!";
while (<$fh>) {
    next if !m/^VANDALREP/;
    my @fields = split(' ');
    next if !exists $panrevs->{$fields[3]};
    my $revid = $fields[3];
    my $long = $fields[5];
    my $class = $panrevs->{$revid}->{class} eq 'vandalism' ? 1 : 0;
    if ($fields[1] eq 'EditLong') {
	# convert to probability
	warn "Crazy long: $long @ $revid" if $long > 1 || $long < -1;
	$long = min($long, 1.0);
	$long = max($long, -1.0);
	$long = (1 + $long) / 2;
	$long = 1 - $long;
	print $editlong "$class $long\n";
	$panrevs->{$revid}->{editlong} = $long;
    } elsif ($fields[1] eq 'TextLong') {
	die "Crazy long: $long @ $revid" if $long > 1 || $long < 0;
	$long = min($long, 1.0);
	$long = max($long, 0);
	$long = 1 - $long;
	print $textlong "$class $long\n";
	$panrevs->{$revid}->{textlong} = $long;
    }
}
close($fh);


open(my $combo, ">weka-combined.csv") || die "open: $!";
print $combo "textlong,editlong,class\n";
foreach my $revid (keys %$panrevs) {
    my $rev = $panrevs->{$revid};
    if (exists $rev->{editlong} && exists $rev->{textlong}) {
	print $combo join(",", $rev->{textlong}, $rev->{editlong},
	    $rev->{class}) . "\n";
    }
    if (!exists $panrevs->{$revid}->{editlong}
	    && !exists $panrevs->{$revid}->{textlong})
    {
	print "Missing both: $revid\n";
	next;
    }
if (0) {
    # This code doesn't actually much improve our performance.
    if (!exists $panrevs->{$revid}->{editlong}) {
	# if we're missing editlong but not textlong,
	# it's likely to be because the edit distance was zero.
	my $class = $panrevs->{$revid}->{class} eq 'vandalism' ? 1 : 0;
	my $long = 0;	    # prob it's vandalism is 0.
	print $editlong "$class $long\n";
    }
} else {
    print "Missing editl: $revid\n" if !exists $panrevs->{$revid}->{editlong};
}
    print "Missing textl: $revid\n" if !exists $panrevs->{$revid}->{textlong};
}
close($combo);

close($editlong);
close($textlong);

exit(0);


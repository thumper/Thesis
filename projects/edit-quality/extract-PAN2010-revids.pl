#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;
use Data::Dumper;
use Date::Manip;
use lib 'lib';
use PAN;

my ($editfile, $goldfile) = @ARGV;

my $edits = {};

readCSV($editfile, [0, 3, 5], sub {
    my ($editid, $newrevid, $date) = @_;
    my $d = ParseDate($date);
    my $secs = UnixDate($d, "%s");
    die "Bad time: $secs, $date" if !defined $secs;
    $edits->{$editid} = { revid => $newrevid, 'time' => $secs };
});

readCSV($goldfile, [0, 1], sub {
    my ($editid, $class) = @_;
    $edits->{$editid}->{class} = $class;
});

print '"revid","time","class"'."\n";
foreach my $editid (keys %$edits) {
    print $edits->{$editid}->{revid}, ",",
	$edits->{$editid}->{'time'}, ",\"",
	$edits->{$editid}->{class}, "\"\n";
}

exit(0);


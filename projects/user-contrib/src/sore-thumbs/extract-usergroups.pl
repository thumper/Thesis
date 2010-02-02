#!/usr/bin/perl

use constant BOUNDARY => 20;

die "wrong number of args" if @ARGV != 0;
my $file = "rankings.txt";

my ($header, $numusers) = getStats($file);

my $lowerBoundary = $numusers / 100 * BOUNDARY;
my $upperBoundary = $numusers - $numusers / 100 * BOUNDARY;


my @header = split(' ', $header);

my $textonly = getCol('textonly');
my $editonly = getCol('editonly');
my $uid = getCol('uid');

my @groups;

open(my $in, "<", $file) || die "open: $!";
my $header = <$in>;
while (<$in>) {
    chomp;
    my @fields = split(' ');
    if ($fields[$textonly] < $lowerBoundary && $fields[$editonly] < $lowerBoundary) {
	push @{ $groups[0] }, $fields[$uid];
    }
    if ($fields[$textonly] < $lowerBoundary && $fields[$editonly] > $upperBoundary) {
	push @{ $groups[1] }, $fields[$uid];
    }
    if ($fields[$textonly] > $upperBoundary && $fields[$editonly] < $lowerBoundary) {
	push @{ $groups[2] }, $fields[$uid];
    }
    if ($fields[$textonly] > $upperBoundary && $fields[$editonly] > $upperBoundary) {
	push @{ $groups[3] }, $fields[$uid];
    }
    if (abs($fields[$textonly] - $fields[$editonly]) < $lowerBoundary/30.0) {
	push @{ $groups[4] }, $fields[$uid];
    }
}
close($in);

open(my $out, ">", "uids-tloelo.txt") || die "open: $!";
foreach (@{ $groups[0] }) {
    print $out "$_\n";
}
close($out);
open($out, ">", "uids-tloehi.txt") || die "open: $!";
foreach (@{ $groups[1] }) {
    print $out "$_\n";
}
close($out);
open($out, ">", "uids-thielo.txt") || die "open: $!";
foreach (@{ $groups[2] }) {
    print $out "$_\n";
}
close($out);
open($out, ">", "uids-thiehi.txt") || die "open: $!";
foreach (@{ $groups[3] }) {
    print $out "$_\n";
}
close($out);
open($out, ">", "uids-midline.txt") || die "open: $!";
foreach (@{ $groups[4] }) {
    print $out "$_\n";
}
close($out);



exit(0);

sub getStats {
    my $numusers = 0;
    open(my $in, "<", $file) || die "open: $!";
    my $header = <$in>;
    while (<$in>) { $numusers++; }
    close($in);
    chomp($header);
    return ($header, $numusers);
}

sub getCol {
    for (my $i = 0; $i < @header; $i++) {
	return $i if $header[$i] eq $_[0];
    }
    return undef;
}

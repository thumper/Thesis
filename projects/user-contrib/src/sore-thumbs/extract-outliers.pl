#!/usr/bin/perl -w

# read in a file of compiled data

use strict;

die "wrong number of args" if @ARGV != 3;

my ($outliers, $datafile, $output) = @ARGV;

my @watch;

open(my $in, "<", $outliers) || die "open: $!";
while (<$in>) {
    my @fields = split(' ');
    my $type = $fields[1];
    my $uid = $fields[3];

    next if !defined $uid;
    next if $uid !~ m/^\d+$/;

    $watch[$type]->{$uid} = 1;
}
close($in);

my @fh;
for (my $i = 0; $i < @watch; $i++) {
    next if !defined $watch[$i];
    open(my $fh, ">", "$output-$i.txt") || die "open: $!";
    $fh[$i] = $fh;
}
open($in, "<", $datafile) || die "open: $!";
while (my $line = <$in>) {
    if ($line =~ m/^(\d+)\b/) {
	my $uid = $1;
	for (my $i = 0; $i < @watch; $i++) {
	    next if !defined $watch[$i];
	    if (exists $watch[$i]->{$uid}) {
		die "undefined in position $i" if !defined $fh[$i];
		my $fh = $fh[$i];
		print $fh $line;
	    }
	}
    }
}
close($in);
for (my $i = 0; $i < @fh; $i++) {
    next if !defined $fh[$i];
    close($fh[$i]);
}
exit(0);


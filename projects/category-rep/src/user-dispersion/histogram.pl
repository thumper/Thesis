#!/usr/bin/perl -w

use strict;
use warnings;

my $col = shift @ARGV;

die "First argument must be a column number"
	if $col !~ m/^\d+$/;

$col--;
die "Column numbers start at one" if $col < 0;

my %data;

while (<>) {
    chomp;
    my @fields = split(/ +/);
    next if @fields <= $col;
    my $numcats = $fields[$col];
    $data{$numcats}++;
}
foreach my $cats (sort { $a <=> $b } keys %data) {
    print "$cats $data{$cats}\n";
}
exit(0);


#!/usr/bin/perl -w
use strict;
use warnings;

my $file = shift @ARGV;

my $totalPages = 0;
my %catFreq;
my %catCofreq;

open(my $rootcatfh, "<:encoding(iso-8859-1)", $file) || die "open($file): $!";
while (<$rootcatfh>) {
    $totalPages++;
    my @cats = split(' ');
    my $pageid = shift @cats;		# throw away
    shift @cats;			# throw away "--"
    @cats = sort { $a <=> $b } @cats;
    # track occurrence of categories
    foreach (@cats) {
	$catFreq{$_}++;
    }
  
    # track co-occurrence of categories
    for (my $i = 0; $i < @cats; $i++) {
	for (my $j = $i+1; $j < @cats; $j++) {
	    $catCofreq{$cats[$i],$cats[$j]}++;
	}
    }
}
close($rootcatfh);

my %covar;
foreach my $i (keys %catFreq) {
    foreach my $j (keys %catFreq) {
	next if $j <= $i;
	my $joint = $catCofreq{$i,$j} || 0;
	my $covariance = $joint/$totalPages - ($catFreq{$i}/$totalPages) * ($catFreq{$j} / $totalPages);
	print "$i\t$j\t$covariance\n";
    }
}

exit(0);


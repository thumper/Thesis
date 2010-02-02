#!/usr/bin/perl -w
use strict;
use warnings;

my (%category_titles);
&readData();


open(my $rootcatfh, "<:encoding(iso-8859-1)", "cat2rootcat.txt") || die "open: $!";
while (<$rootcatfh>) {
    my @cats = split(' ');
    my $cat = getCatnameFId(shift @cats);
    shift @cats;
    print "$cat -- ", join(' ', map { getCatnameFId($_) } @cats), "\n";
}
close($rootcatfh);

exit(0);

sub getCatnameFId {
    my $cat = shift @_;
    return $category_titles{$cat};
}

sub readData {
    open(CATLOOKUP, "<:encoding(iso-8859-1)", "catidname.txt");
    while (<CATLOOKUP>) {
	chomp;
	my ($key, $val) = split(/ -- /);
	$category_titles{$key} = $val;
    }
    close CATLOOKUP;
}


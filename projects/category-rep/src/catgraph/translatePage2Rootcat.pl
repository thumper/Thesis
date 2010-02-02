#!/usr/bin/perl -w
use strict;
use warnings;

my (%category_titles, %page_names);
&readData();


open(my $rootcatfh, "<:encoding(iso-8859-1)", "page2rootcat.txt") || die "open: $!";
while (<$rootcatfh>) {
    my @cats = split(' ');
    my $page = $page_names{(shift @cats)};
    shift @cats;
    print "$page -- ", join(' ', map { getCatnameFId($_) } @cats), "\n";
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

    open(PAGELOOKUP, "<:encoding(iso-8859-1)", "pageidname.txt");
    while (<PAGELOOKUP>) {
	chomp;
	my ($key, $val) = split(/ -- /);
	$page_names{$key} = $val;
    }
    close PAGELOOKUP;
}


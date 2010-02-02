#!/usr/bin/perl -w
use strict;
use warnings;

$| = 1;

my (%category_graph_ids, %category_titles,
	%category_pages, %page_names);
&readData();

my %seenPages;
my $numpages = 0;

foreach my $cat (@ARGV) {
    my $catid = getIdFCatname($cat);
    print "Category '$cat': catid=$catid\n";
    my $idList = [ $catid ];
    foreach my $level(0..2) {
	my $numpages = 0;
	my @subcats;
	foreach my $id (@$idList) {
	    if (exists $category_pages{$id}) {
		foreach my $pageid (@{$category_pages{$id}}) {
		    $numpages++ if !exists $seenPages{$pageid};
		    $seenPages{$pageid} = 1;
		}
	    }
	    push @subcats, @{ $category_graph_ids{$id} } if exists $category_graph_ids{$id};
	}
	my $numsubcats = scalar(@subcats);
	print "level $level\tnumpages $numpages\tnumsubcats $numsubcats\n";
	print "\tcats ", (map { $category_titles{$_}. " " } @subcats), "\n";
	$idList = \@subcats;
    }
}

exit(0);

sub getIdFCatname {
    my $cat = shift @_;
    foreach my $key (keys %category_titles) {
	return $key if $category_titles{$key} eq $cat;
    }
    return undef;
}

sub readData {
    open(GRAPH,"<:encoding(iso-8859-1)", "graph.txt");
    while (<GRAPH>) {
	chomp;
	my @vals = split(' ');
	my $key = shift @vals;
	die "bad val: $_" if (shift @vals) ne '--';
	$category_graph_ids{$key} = \@vals;
    }
    close GRAPH;

    open(CATLOOKUP, "<:encoding(iso-8859-1)", "catidname.txt");
    while (<CATLOOKUP>) {
	chomp;
	my ($key, $val) = split(/ -- /);
	$category_titles{$key} = $val;
    }
    close CATLOOKUP;

    open(CATPAGES, "<:encoding(iso-8859-1)", "catpages.txt");
    while (<CATPAGES>) {
	chomp;
	my @vals = split(' ');
	my $key = shift @vals;
	die "bad val: $_" if (shift @vals) ne '--';
	$category_pages{$key} = \@vals;
    }
    close CATPAGES;

#    open(PAGELOOKUP, "<:encoding(iso-8859-1)", "pageidname.txt");
#    while (<PAGELOOKUP>) {
#	chomp;
#	my ($key, $val) = split(/ -- /);
#	$page_names{$key} = $val;
#    }
#    close PAGELOOKUP;
}

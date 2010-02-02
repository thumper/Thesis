#!/usr/bin/perl
use strict;
use warnings;
use Encode;
use PerlIO::encoding;
use PerlIO::gzip;

##Open the files
my ($category_filename, $pageinfo_filename) = @ARGV;

print "Category filename: $category_filename\n";
print "Pageinfo filename: $pageinfo_filename\n";



##Since we're only dealing with the category hierarchy here, we only
##need to know about pages within the category namespace (number 14)

print "Generating category hashes...\n";

##Save off two hashes of category ids and titles, also a hash of pages in the main namespace
my %category_titles;    #indexed by id
my %category_ids;       #indexed by title
my %page_names;         #indexed by id

open(my $catlookup, ">:encoding(iso-8859-1)", "catidname.txt");
open(my $pagelookup, ">:encoding(iso-8859-1)", "pageidname.txt");

open(PAGEINFO, "<:gzip :encoding(ISO-8859-1)", $pageinfo_filename) || die "open: $!";
while (<PAGEINFO>) {
    while (m/\((\d+),(\d+),'(.+?)','.*?',\d+,\d+,/g) {
	my $id = $1;
	my $namespace = $2;
	my $name = $3;
	if ($namespace == 14) {
	    print $catlookup "$id -- $name\n";
	    $category_titles{$id} = 1;
	    $category_ids{$name} = $id;
	} elsif ($namespace == 0) {
	    print $pagelookup "$id -- $name\n";
	    $page_names{$id} = 1;
	}
    }
}
close PAGEINFO;
close $catlookup;
close $pagelookup;

print "Building category category tables...\n";

##Now go through the category links table and build a graph
my %category_graph_ids; #Indexed by ID, contains list of child category IDs
my %category_pages; #Indexed by catid, contains page ids in this category
open(CATEGORY, "<:gzip :encoding(ISO-8859-1)", $category_filename) || die "open: $!";
while (<CATEGORY>) {
    while (m/\((\d+),'(.+?)','.*?',\d+\)/g) {
	my $id = $1;
	my $name = $2;
	next if !defined $category_ids{$name};		# we only want category containers
	my $catid = $category_ids{$name};
	if (exists $category_titles{$id}) {
	    #If the ID corresponds to a category
	    # in the case where both ID and NAME are defined in our
	    # category hashes, then NAME is the parent category of ID.
	    $category_graph_ids{$catid} = []
			if !exists $category_graph_ids{$catid};
	    push(@{$category_graph_ids{$catid}}, $id);
	} elsif (exists $page_names{$id}) {
	    # If the ID corresponds to a main namespace page
	    #Add the category to the graph if not already defined
	    $category_pages{$catid} = [] if !defined($category_pages{$catid});
	    
	    #Add the page to this category
	    push(@{$category_pages{$catid}}, $id);
	}
    }
}
close CATEGORY;

print "Writing remaining output files...\n";

open(my $graph,">:encoding(iso-8859-1)", "graph.txt");
while (my ($key, $val) = each %category_graph_ids) {
    print $graph "$key -- @$val\n";
}
close $graph;


open(my $catpages, ">:encoding(iso-8859-1)", "catpages.txt");
while (my ($key, $val) = each %category_pages) {
    print $catpages "$key -- @$val\n";
}
close $catpages;

exit(0);


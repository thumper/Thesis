#!/usr/bin/perl -w
use strict;
use warnings;

my (%category_graph_ids, %category_titles, %catsFPageId);
&readData();


my %seen;
my $mainTopicId = getIdFCatname("Main_topic_classifications");
die "no topic id" if !defined $mainTopicId;

my $rootCategories = $category_graph_ids{$mainTopicId};

my (%assignedRootCategories);

foreach my $root (@$rootCategories) {
    # Mark these as already assigned
    $assignedRootCategories{$root} = { level => 0, cats => [ $root ] };
}
foreach my $root (@$rootCategories) {
    # Traverse down the tree, setting each one back to us.
    print "Marking root $root\n";
    markParent($root, 1, $category_graph_ids{$root});
}

# write out everything we figured out
open(my $rootcatfh, ">:encoding(iso-8859-1)", "cat2rootcat.txt") || die "open: $!";
foreach my $cat (keys %assignedRootCategories) {
    print $rootcatfh "$cat -- ", join(' ', @{ $assignedRootCategories{$cat}->{cats} }), "\n";
}
close($rootcatfh);

# and go back and figure it out for pages
open(my $pagecatfh, ">:encoding(iso-8859-1)", "page2rootcat.txt") || die "open: $!";
foreach my $pageId (keys %catsFPageId) {
    my $cats = $catsFPageId{$pageId};
    my @parentCats;
    foreach my $cat (@$cats) {
	if (exists $assignedRootCategories{$cat}) {
	    push @parentCats, @{ $assignedRootCategories{$cat}->{cats} }
	} else {
	    # If the category wasn't reachable from one our roots,
	    # ignore it.
	    # old code: push @parentCats, $cat;
	}
    }
    my %parentCats = map { $_ => 1 } @parentCats;
    print $pagecatfh "$pageId -- ".join(' ', keys %parentCats)."\n";
}
close($pagecatfh);

exit(0);

sub markParent {
    my ($rootId, $level, $subcats) = @_;
    return if !defined $subcats;
    foreach my $cat (@$subcats) {
	if (!exists $assignedRootCategories{$cat}) {
	    $assignedRootCategories{$cat} = { level => $level, cats => [ $rootId] };
	    markParent($rootId, $level+1, $category_graph_ids{$cat});
	} elsif ($level < $assignedRootCategories{$cat}->{level}) {
	    $assignedRootCategories{$cat} = { level => $level, cats => [ $rootId] };
	    markParent($rootId, $level+1, $category_graph_ids{$cat});
	} elsif ($level == $assignedRootCategories{$cat}->{level}) {
	    # have we already seen this one
	    return if scalar(
			grep {$_ == $rootId}
			@{ $assignedRootCategories{$cat}->{cats} }
		    ) > 0;
	    push @{ $assignedRootCategories{$cat}->{cats} }, $rootId;
	    markParent($rootId, $level+1, $category_graph_ids{$cat});
	}
    }
}
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

    open(CATPAGES, "<:encoding(iso-8859-1)", "catpages.txt");
    while (<CATPAGES>) {
	chomp;
	my @vals = split(' ');
	my $key = shift @vals;
	die "bad val: $_" if (shift @vals) ne '--';
	foreach my $id (@vals) {
	    $catsFPageId{$id} = [] if !exists $catsFPageId{$id};
	    push @{ $catsFPageId{$id} }, $key;
	}
    }
    close CATPAGES;

    open(CATLOOKUP, "<:encoding(iso-8859-1)", "catidname.txt");
    while (<CATLOOKUP>) {
	chomp;
	my ($key, $val) = split(/ -- /);
	$category_titles{$key} = $val;
    }
    close CATLOOKUP;
}


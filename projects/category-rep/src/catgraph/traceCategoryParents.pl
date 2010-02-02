#!/usr/bin/perl -w
use strict;
use warnings;

$| = 1;

my (%reverse_graph_ids, %category_titles);
&readData();


my %seen;
my $mainTopicId = getIdFCatname("Main_topic_classifications");
die "no topic id" if !defined $mainTopicId;

foreach my $cat (@ARGV) {
    my $catid = getIdFCatname($cat);
    print "Category '$cat': catid=$catid\n";
    my $idList = [ $catid ];
    foreach my $level(0..10) {
	my $numpages = 0;
	my @parentcats;
	foreach my $id (@$idList) {
	    next if !defined $id;
	    if (exists $reverse_graph_ids{$id}) {
		push @parentcats, grep { !exists $seen{$_} } @{ $reverse_graph_ids{$id} };
		foreach my $s (@{ $reverse_graph_ids{$id} }) {
		    $seen{$s} = 1;
		    if ($s == $mainTopicId) {
			print "MAIN TOPIC: ", $category_titles{$id}, "\n";
		    }
		}
	    }
	}
	my $numparcats = scalar(@parentcats);
	print "level $level\tnumparentcats $numparcats\n";
	print "\tcats ", (map { $category_titles{$_}. " " } @parentcats), "\n";
	$idList = \@parentcats;
	last if $numparcats == 0;
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
	# we want the reverse graph, though.
	foreach my $id (@vals) {
	    $reverse_graph_ids{$id} = [] if !exists $reverse_graph_ids{$id};
	    push @{ $reverse_graph_ids{$id} }, $key;
	}
    }
    close GRAPH;

    open(CATLOOKUP, "<:encoding(iso-8859-1)", "catidname.txt");
    while (<CATLOOKUP>) {
	chomp;
	my ($key, $val) = split(/ -- /);
	$category_titles{$key} = $val;
    }
    close CATLOOKUP;
}


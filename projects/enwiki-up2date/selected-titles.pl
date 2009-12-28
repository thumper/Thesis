#!/usr/bin/perl

use strict;
use warnings;
use open IN => ':utf8', OUT => ':utf8';
use LWP::UserAgent;
use HTML::Entities;

use constant BASEURL => 'http://en.wikipedia.org/wiki/Wikipedia:0.7/0.7alpha/';

binmode \*STDOUT, ":utf8";

foreach my $letter ('A'..'Z', 'Misc') {
    my $page = 1;
    my $results;
    do {
	$results = getLetter($letter, $page);
	foreach (@$results) {
	    print "$_\n";
	}
	$page++;
    } while @$results > 0;
}
exit(0);


sub getLetter {
    my ($letter, $page) = @_;

    my $url = BASEURL.$letter.$page;
warn "URL[$url]";
    my $ua = LWP::UserAgent->new;
    $ua->agent("Mozilla/8.0");
    my $req = HTTP::Request->new(GET => $url);
    my $res = $ua->request($req);

    return [] if !$res->is_success && $res->status_line =~ m/^404 /;
    die "Error getting [$url]: ".$res->status_line if !$res->is_success;

    my $content = $res->decoded_content;

    die "Unable to get [$url]" if !defined $content;

    my @results;
    $content =~ s/^.*\.showTocToggle//s;
    $content =~ s/NewPP.*$//s;
    while ($content =~ m#href="/wiki/[^"]+" title="([^"]+)"#g) {
	next if $1 =~ m/Wikipedia:0.7/;
	my $title = $1;
	decode_entities($title);
	push @results, $title;
    }
    return \@results;
}



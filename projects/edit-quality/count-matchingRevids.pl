#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use lib 'lib';
use PAN;
use MediawikiDump;

my ($revids, $dumpFileOrDir) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 3], sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
});

my $count = 0;
my $dump = MediawikiDump->new(\&page_start, \&page_end, sub {
	$count += rev_handler($panrevs, @_);
    });
$dump->process($dumpFileOrDir);
print "Found $count matching revids\n";
foreach my $revid (keys %$panrevs) {
    next if $panrevs->{$revid}->{seen};
    print "Skipped revid $revid\n";
}
exit(0);

sub page_start {
    my $data = shift @_;
    #my $xs = XML::Simple->new(ForceArray => 1);
    #my $p = $xs->XMLin(join('', @{ $data->{lines} }));
}
sub page_end {
}
sub rev_handler {
    my ($panrevs, $data) = @_;
if (0) {
    my $xs = XML::Simple->new(ForceArray => 1);
    my $p = $xs->XMLin(join('', @{ $data->{lines} }));
    my $revid = $p->{id}->[0];
}
    my $revid = undef;
    foreach ( @{ $data->{lines} } ) {
	if (m/^\s*<id>(\d+)<\/id>/) {
	    $revid = $1;
	    last;
	}
    }
    die "Revision has no id?" if !defined $revid;
    if (exists $panrevs->{$revid}) {
	die "Duplicate revid $revid" if exists $panrevs->{$revid}->{seen};
	$panrevs->{$revid}->{seen} = 1;
	return 1;
    }
    return 0;
}


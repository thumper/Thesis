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

readCSV($revids, [0, 1], sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
});

my $count = 0;
my $dump = MediawikiDump->new(\&page_start, \&page_end, sub {
	$count += rev_handler($panrevs, @_);
    });
$dump->process($dumpFileOrDir);
print "Found $count matching revids\n";
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
    my $xs = XML::Simple->new(ForceArray => 1);
    my $p = $xs->XMLin(join('', @{ $data->{lines} }));
    my $revid = $p->{id}->[0];
    if (exists $panrevs->{$revid}) {
	die "Duplicate revid $revid" if exists $panrevs->{$revid}->{seen};
	$panrevs->{$revid}->{seen} = 1;
	return 1;
    }
    return 0;
}


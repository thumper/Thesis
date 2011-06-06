#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use List::Util qw( min max );
use lib '../edit-quality/lib';
use PAN;
use MediawikiDump;

my ($revids, $repFile) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 1, 2, 3], sub {
    my ($revid, $t, $author, $class) = @_;
    $panrevs->{$revid} = { 'time' => $t, author => $author,
			    class => $class };
});

my @revids = sort { $panrevs->{$a} <=> $panrevs->{$b} } keys %$panrevs;

my $nextrev = shift @revids;
my $nexttime = $panrevs->{$nextrev}->{'time'};
print "NEXT:  rev=$nextrev, time=$nexttime\n";
my $authorRep = {};

open(my $repf, ">perf-reputation.txt") || die "open: $!";
print $repf "Time,Revid,Rep,RepBin,Vandalism\n";

open(my $fh, "<", $repFile) || die "open($repFile): $!";
while (defined ($_ = <$fh>) && defined $nextrev) {
    next if !m/^VANDALREP/;
    my $author = '';
    if (m/"([^"]+)"/) {
	$author = $1;
    }
    my @fields = split(' ');
    my $t = $fields[2];
    next if $t eq 'rev:';
    while (defined $nextrev && $t > $nexttime) {
	print "t = $t\nt'= $nexttime\n";
	# Now it's safe to look up the rep of the author
	my $a = $panrevs->{$nextrev}->{author};
	my $rep = $authorRep->{$a} || [0, 0];
	my $class = $panrevs->{$nextrev}->{class};
	print $repf join(',', $nexttime, $nextrev, @$rep, $class), "\n";
	$nextrev = shift @revids;
	$nexttime = $panrevs->{$nextrev}->{'time'} if defined $nextrev;
    }
    my $newrep = $fields[7];
    my $newrepbin = $fields[6];
    $authorRep->{$author} = [$newrep, $newrepbin];
}
close($fh);

close($repf);

exit(0);


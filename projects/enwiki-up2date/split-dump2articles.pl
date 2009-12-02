#!/usr/bin/perl

# Read a dump on stdin, and write out to article files

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";

use constant OUTDIR => "./ensplit2-20080103/";

use File::Path qw(mkpath);

$SIG{CHLD} = 'IGNORE';

my ($line, $collected);

my $counter = 0;

while (defined($line = <STDIN>)) {
    $collected = "";
    pageStart();
    my $id = pageId();
    die "Bad id" if !defined $id;
    my $longid = sprintf("%012d", $id);
    my $dir = substr($longid, -3);
    my $outdir = OUTDIR . $dir;
    mkpath($outdir, { verbose => 1, mode => 0750 }) if !-d $outdir;
    my $base = $outdir.'/'.$longid;
    open(OUT, '>'.$base.".meta") || die "open($base.meta): $!";
    print OUT $collected;
    close(OUT);
    copyRevisions($base);
    $counter++;
}
print "processed $counter pages\n";
exit(0);

sub pageStart {
    while (defined $line && $line !~ m/^\s*<page>/) {
	$line = <STDIN>;
    }
}

sub pageId {
    while (defined $line) {
	$collected .= $line;
	if ($line =~ m#^\s*<id>(\d+)</id>#) {
	    return $1;
	}
	$line = <STDIN>
    }
    return undef;
}

sub copyRevisions {
    my $base = shift @_;
    open(OUT, ">".$base) || die "open($base): $!";
    while (defined($line = <STDIN>)) {
	last if $line =~ m#^\s*</page>#;
	print OUT $line;
    }
    close(OUT);
    my $pid = fork();
    if (!$pid) {
	exec("bzip2 -9 -q $base");
	exit(0);
    }
}


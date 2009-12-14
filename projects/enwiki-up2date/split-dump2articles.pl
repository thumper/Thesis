#!/usr/bin/perl

# Read a dump on stdin, and write out to article files

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";

use constant OUTDIR => "./ensplit4-20080103/";

use File::Path qw(mkpath);
use IO::Handle '_IOLBF';

$SIG{CHLD} = 'IGNORE';

my ($line, $collected);

my $counter = 0;

my $io = new IO::Handle;
$io->fdopen(fileno(STDIN),"r") || die "fdopen: $!";
# NOTE: does not work on perlio mode
##my $buffer;
##$io->setvbuf($buffer, _IOLBF, 0x1000000);


while (defined($line = $io->getline)) {
    $collected = "";
    pageStart();
    last if !defined $line;
    my $id = pageId();
    die "Bad id" if !defined $id;
    my $longid = sprintf("%012d", $id);
    my @dirs = map { substr($longid, $_, 3) } (0, 3, 6);
    my $outdir = OUTDIR . join('/', @dirs);
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
	$line = $io->getline;
    }
}

sub pageId {
    while (defined $line) {
	$collected .= $line;
	if ($line =~ m#^\s*<id>(\d+)</id>#) {
	    return $1;
	}
	$line = $io->getline;
    }
    return undef;
}

sub copyRevisions {
    my $base = shift @_;
    open(OUT, ">".$base) || die "open($base): $!";
    while (defined($line = $io->getline)) {
	last if $line =~ m#^\s*</page>#;
	print OUT $line;
    }
    close(OUT);
    my $pid = fork();
    if (!$pid) {
	exec("pbzip2 -9 -q $base");
	exit(0);
    }
}


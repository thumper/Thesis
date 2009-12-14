#!/usr/bin/perl

# Assume that a dump is fully uncompressed.
# Fork a bunch of processes to deal with the different pieces.

# uses the WideFinder perl idea of using mmap 
# Seems to work, but perl fails for files larger than 2G

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";
use Sys::Mmap;

use constant OUTDIR => "./ensplit4-20080103/";
use constant SRCDIR2 => "./ensplit-20080103/";		# previously sorted articles

use File::Path qw(mkpath);

my $input = shift @ARGV;

my $subprocesses = 0;
my $offset = 0;
my $maxsize = -s $input;
my $handlesize = 16 * 1024 * 1024;

while ($offset < $maxsize) {
    while ($subprocesses > 10) {
	my $kid = waitpid(-1, 0);
	die "bad kid: $kid" if $kid < 0;
	die "child died badly: $?" if $? != 0;
	$subprocesses--;
    }
    $subprocesses++;
    my $pid = fork();
    if (!$pid) {
	processFile($input, $offset, $handlesize);
	exit(0);
    } else {
	$offset += $handlesize;
    }
}
while ($subprocesses > 0) {
    my $kid = waitpid(-1, 0);
    $subprocesses--;
}
exit(0);

sub min {
    my ($a, $b) = @_;
    if ($a <= $b) { return $a; }
    else { return $b; }
}

sub processFile {
    my ($input, $offset, $handlesize) = @_;

    my $maxsize = -s $input;
    my $endpos = min($maxsize, $offset + $handlesize);
warn "Scanning $offset to $endpos";

    my $data;
    open(ORIG, $input) || die "open($input): $!";
    mmap($data, 0, PROT_READ, MAP_SHARED, ORIG) || die "mmap: $!";


    my $pos = $offset;
    while ($pos < $endpos) {
	pos($data) = $pos;
	my $page_start = undef;
	if ($data =~ m{<page>}g) { $page_start = pos($data) - length("<page>"); }
	else { last; };
	last if $page_start >= $endpos;	# next page starts past boundary

	my $rev_start = undef;
	if ($data =~ m#<revision>#g) { $rev_start = pos($data) - length("<revision>"); }
	else { die "No revision found after $page_start"; }
	die "Happens before: $rev_start < $page_start" if $rev_start < $page_start;

	my $page_end = undef;
	if ($data =~ m#</page>#g) { $page_end = pos($data) - length("</page>"); }
	else { die "No page end found after $rev_start"; }

	my $id = undef;
	if (substr($data, $page_start, $rev_start-$page_start) =~ m#<id>(\d+)</id>#) {
	    $id = $1;
	} else { die "No id found, starting at $page_start"; }
	my $title = undef;
	if (substr($data, $page_start, $rev_start-$page_start) =~ m#<title>(.*)</title>#) {
	    $title = $1;
	} else { die "No title found, starting at $page_start"; }

	# Skip all articles that aren't in the main name space
	if ($title =~ m/^(Media|Special|Talk|User|User talk|Wikipedia|Wikipedia talk|Image|Image talk|MediaWiki|MediaWiki talk|Template|Template talk|Help|Help talk|Category|Category talk|Portal|Portal talk):/)
	{
	    $pos = $page_end + length("</page>");
	    next;
	}

	my $longid = sprintf("%012d", $id);
	my @dirs = map { substr($longid, $_, 3) } (0, 3, 6);
	my $outdir = OUTDIR . join('/', @dirs);
	mkpath($outdir, { verbose => 1, mode => 0750 }) if !-d $outdir;
	my $base = $outdir.'/'.$longid;

	open(OUT, '>'.$base.".meta") || die "open($base.meta): $!";
	print OUT substr($data, $page_start, $rev_start-$page_start);
	close(OUT);

	# Copy all revisions, plus those we downloaded previously
	my $len = $page_end - $rev_start;
	$pos = $rev_start;
	open(OUT, "| pbzip2 -9 -c > $base.bz2") || die "open($base.gz): $!";
	# First, copy from our dump file
	while ($len > 0) {
	    my $s = min($len , 1 * 1024 * 1024);
	    print OUT substr($data, $pos, $s);
	    $pos += $s;
	    $len -= $s;
	}
if (0) {
	# and now also find what we downloaded
	my $olddir = SRCDIR2 . join("/", map { substr($longid, $_, 3) } (0,3,6,9) );
	if (-f "$olddir/revisions.txt.gz") {
	    open(INPUT, "gunzip -c $olddir/revisions.txt.gz |") || die "open: $!";
	    my $buffer;
	    while (1) {
		my $read = sysread(INPUT, $buffer, 1 * 1024 * 1024, 0);
		last if $read == 0;
		print OUT $buffer;
	    }
	    close(INPUT);
	}
}
	close(OUT);
	$pos = $page_end + length("</page>");
    }
    munmap($data) || die "munmap: $!";
    close(ORIG);
}


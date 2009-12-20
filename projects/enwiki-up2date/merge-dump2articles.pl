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
use File::Path qw(mkpath);

use constant OUTDIR => "./ensplit4-20080103.mmap/";
use constant SRCDIR2 => "./ensplit-20080103.mmap/";		# previously sorted articles

use constant STATE_MULTIPAGE => 0;
use constant STATE_LASTPAGE => 1;
use constant STATE_DONE => 2;

my $input = shift @ARGV;

my $subprocesses = 0;
my $offset = 0;
my $maxsize = -s $input;
my $handlesize = 1800 * 1024 * 1024;

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
	processChunk($input, $offset, $handlesize);
	exit(0);
    } else {
	$offset += $handlesize - (length("<page>")-1);
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

sub processChunk {
    my ($input, $offset, $handlesize) = @_;

    my $maxsize = -s $input;

    my $state = STATE_MULTIPAGE;
    while ($state != STATE_DONE && $offset < $maxsize) {
	my $len = min($handlesize, $maxsize - $offset);
	($offset, $state) = doChunkAction($input, $offset, $len, $state);
warn "doChunkAction = ($offset, $state)\n";
    }
}


sub doChunkAction {
    my ($input, $offset, $len, $state) = @_;
    my $next_state = STATE_DONE;
my $endpos = $offset+$len;
warn "Scanning $offset to $endpos";

    my $data;
    open(ORIG, $input) || die "open($input): $!";
    mmap($data, $len, PROT_READ, MAP_SHARED, ORIG, $offset) || die "mmap: $!";


    my $pos = 0;
    while ($pos < $len) {
	pos($data) = $pos;
	my $page_start = undef;

	if ($data =~ m{<page>}g) { $page_start = pos($data) - length("<page>"); }
	else {
	    # No page data in this chunk, so someone else handled it.
	    last;
	}

	my $rev_start = undef;
	if ($data =~ m#<revision>#g) {$rev_start = pos($data) - length("<revision>"); }
	else {
	    # Were we too close to end of the chunk?
	    if ($page_start > 0) {
		$pos = $page_start;
		$next_state = STATE_LASTPAGE;
		last;
	    }
	    die "No revision found after $offset+$page_start";
	}
	die "Happens before: $rev_start < $page_start" if $rev_start < $page_start;

	pos($data) = $page_start;
	my $id = undef;
	if ($data =~ m#<id>(\d+)</id>#g) {
	    $id = $1;
	    die "Id too far @ ".pos($data).", page @ $offset+$page_start" if pos($data) - $page_start > 400;
	} else {
	    if ($page_start > 0) {
		$pos = $page_start;
		$next_state = STATE_LASTPAGE;
		last;
	    }
	    die "No id found, starting at $page_start";
	}
	pos($data) = $page_start;
	my $title = undef;
	if ($data =~ m#<title>(.*)</title>#g) {
	    $title = $1;
	    die "Title too far @ ".pos($data).", page @ $offset+$page_start" if pos($data) - $page_start > 200;
	} else {
	    if ($page_start > 0) {
		$pos = $page_start;
		$next_state = STATE_LASTPAGE;
		last;
	    }
	    die "No title found, starting at $page_start";
	}

	my $page_end = undef;
	if ($data =~ m#</page>#g) { $page_end = pos($data) - length("</page>"); }
	else {
	    if ($page_start > 0) {
		$pos = $page_start;
		$next_state = STATE_LASTPAGE;
		last;
	    }
	    # We should die here, but there are some talk pages
	    # which are longer than 1GB.  So set the maxlen
	    # (which is actually impossible), and check for
	    # it later.  This allows us to "skip" Talk pages.
	    $page_end = $len;
	}

	if ($rev_start > $page_end) {
	    $pos = $page_end + length("</page>");
	    last if $state == STATE_LASTPAGE;
	    next;
	}

	# Skip all articles that aren't in the main name space
	if ($title =~ m/^(Media|Special|Talk|User|User talk|Wikipedia|Wikipedia talk|Image|Image talk|MediaWiki|MediaWiki talk|Template|Template talk|Help|Help talk|Category|Category talk|Portal|Portal talk):/)
	{
	    $pos = $page_end + length("</page>");
	    last if $state == STATE_LASTPAGE;
	    next;
	}

	# Check for impossible case here, which means a "real" page
	# is longer than our $handlesize.
	die "No page end found for $offset+$page_start" if $page_end == $len;

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
	open(OUT, "| pbzip2 -9 -q -c > $base.bz2") || die "open($base.gz): $!";
	# First, copy from our dump file
	while ($len > 0) {
	    my $s = min($len , 1 * 1024 * 1024);
	    print OUT substr($data, $pos, $s);
	    $pos += $s;
	    $len -= $s;
	}
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
	close(OUT);
	$pos = $page_end + length("</page>");
	last if $state == STATE_LASTPAGE;
    }
    munmap($data) || die "munmap: $!";
    close(ORIG);
    return ($offset+$pos, $next_state);
}


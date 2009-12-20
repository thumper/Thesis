#!/usr/bin/perl

# Merges the file-per-article output from split-dump2articles.pl
# with the file-per-article output from sort-articles.pl
#
# Another program will take care of removing duplicates
# and sorting revisions by timestamp.

use constant SRCDIR1 => "./ensplit2-20080103/";		# split from dump
use constant SRCDIR2 => "./ensplit-20080103/";		# previously sorted articles
use constant OUTDIR => "./ensplit3-20080103/";

use strict;
use warnings;
use File::Find;
use Data::Dumper;
use File::Path qw(mkpath);



find({ wanted => \&mergeFDump, no_chdir=>1 }, SRCDIR1);
find({ wanted => \&mergeFDownload, no_chdir=>1 }, SRCDIR2);

exit(0);

sub mergeFDownload {
    my $file = $File::Find::name;
    return if -d $file;
    return if $file !~ m#/revisions\.txt\.gz$#;

    my $pageid = $file;
    $pageid =~ s#^.*\-20080103/##;
    $pageid =~ s#/revisions\.txt\.gz$##;
    $pageid =~ s#/##g;
    die "Bad pageid: [$pageid]" if length($pageid) != 12;



    my $meta = $file;
    $meta =~ s/revisions\.txt\.gz/meta.txt/;

    open(INPUT, $meta) || die "open($meta): $!";
    my $title = <INPUT>;
    chomp($title);
    close(INPUT);

    next if ($title =~ m/<title>(?:Media|Special|Talk|User|User talk|Wikipedia|Wikipedia talk|Image|Image talk|MediaWiki|MediaWiki talk|Template|Template talk|Help|Help talk|Category|Category talk|Portal|Portal talk):/);
    next if $title eq '';
    die "Bad title: $file" if $title eq '';

    my $outdir = OUTDIR . join("/", map { substr($pageid, $_, 3) } (0,3,6) );
    mkpath($outdir, { verbose => 1, mode => 0750 });

    open(OUTPUT, ">$outdir/$pageid.meta") || die "open($outdir/$pageid.meta): $!";
    print OUTPUT "<page>\n<title>", xmlEscape($title), "</title>\n<id>$pageid</id>\n";
    close(OUTPUT);

    rename($file, "$outdir/$pageid.gz") || die "rename($file): $!";

    unlink($meta) || die "unlink($meta): $!";

}

sub mergeFDump {
    my $file = $File::Find::name;
    return if -d $file;
    return if $file !~ m/\.bz2$/;

    my $pageid;
    if ($file =~ m#/(\d+)\.bz2$#) {
	$pageid = $1;
	die "Bad pageid: [$pageid]" if length($pageid) != 12;
    } else {
	die "Unable to parse filename: $file\n";
	return;
    }

    my $meta = $file;
    $meta =~ s/\.bz2$/.meta/;

    my $bad = 0;
    open(INPUT, $meta) || die "open($meta): $!";
    while(<INPUT>) {
	$bad = 1 if m/<title>Talk:/;
	$bad = 1 if m/<title>Image:/;
	$bad = 1 if m/<title>Wikipedia:/;
	$bad = 1 if m/<title>User:/;
	$bad = 1 if m/<title>Template:/;
    }
    close(INPUT);
    if ($bad) {
	unlink($meta) || die "unlink($meta): $!";
	unlink($file) || die "unlink($file): $!";
	return;
    }

    my $outdir = OUTDIR . join("/", map { substr($pageid, $_, 3) } (0,3,6) );
    mkpath($outdir, { verbose => 1, mode => 0750 });

    rename($meta, $outdir."/$pageid.meta") || die "rename($meta): $!";

    my $buffer = '';
    open(OUTPUT, "| gzip --best > $outdir/$pageid.gz") || die "open: $!";
    open(INPUT, "bzcat $file |") || die "open: $!";
    while (1) {
	my $read = sysread(INPUT, $buffer, 1 * 1024 * 1024, 0);
	last if $read == 0;
	my $pos = 0;
	while ($pos < $read) {
	    my $written = syswrite(OUTPUT, $buffer, $read - $pos, $pos);
	    $pos += $written;
	}
    }
    close(INPUT);

    my $downloaded = 
    my $olddir = SRCDIR2 . join("/", map { substr($pageid, $_, 3) } (0,3,6,9) );
    if (-f "$olddir/revisions.txt.gz") {
	unlink($olddir."/meta.txt");
	open(INPUT, "gunzip -c $olddir/revisions.txt.gz |") || die "open: $!";
	while (1) {
	    my $read = sysread(INPUT, $buffer, 1 * 1024 * 1024, 0);
	    last if $read == 0;
	    my $pos = 0;
	    while ($pos < $read) {
		my $written = syswrite(OUTPUT, $buffer, $read - $pos, $pos);
		$pos += $written;
	    }
	}
	close(INPUT);
	rename("$olddir/revisions.txt.gz", "$olddir/revs.txt.gz") || die "rename($olddir): $!";
    }

    close(OUTPUT);
    unlink($file) || die "unlink($file): $!";
}


sub xmlEscape {
    $_[0] =~ s/\&/&amp;/g;
    $_[0] =~ s/\"/&quot;/g;
    $_[0] =~ s/\</&lt;/g;
    $_[0] =~ s/\>/&gt;/g;
}



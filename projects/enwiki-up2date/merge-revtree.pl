#!/usr/bin/perl

# Scans the revision tree of already-downloaded revisions,
# figures out the pageid/revid,
# and blindly appends to the end of the existing single-file version.
# Another program will take care of removing duplicates
# and sorting revisions by timestamp.

use constant SRCDIR => "./wikipedia-0.7/unpack/";
use constant OUTDIR => "./ensplit-20080103/";

use constant WIKIDB => "DBI:mysql:database=wikidb-thumper:host=localhost";
#use constant DBUSER => "wikiuser";
#use constant DBPASS => "wikiword";
use constant DBUSER => "debian-sys-maint";
use constant DBPASS => "OSNZHR9DOKOf5lfT";

use strict;
use warnings;
use File::Find;
use IO::Zlib;
use Data::Dumper;
use File::Path qw(mkpath);
use DBD::mysql;
use DBI;


my $last_pageid = -1;
my $last_tmp = undef;
my $last_cleanup = undef;

my $dbh = DBI->connect(WIKIDB, DBUSER, DBPASS);
die "Bad db: ".$dbh->errstr if !defined $dbh;
my $sth_rev = $dbh->prepare("SELECT rev_id, rev_timestamp, rev_user, rev_user_text, rev_minor_edit, rev_comment FROM revision WHERE rev_id = ?");
my $sth_page = $dbh->prepare("SELECT page_title FROM page WHERE page_id = ?");

find({ wanted => \&wanted, no_chdir=>1 }, SRCDIR);
$last_cleanup->() if defined $last_cleanup;
exit(0);

sub wanted {
    my $file = $File::Find::name;
    return if -d $file;

    my ($pageid, $revid);
    if ($file =~ m#/(\d+)_(\d+)\.gz$#) {
	$pageid = $1;
	$revid = $2;
	die "Bad pageid: [$pageid]" if length($pageid) != 12;
    } else {
	die "Unable to parse filename: $file\n";
	return;
    }

    $sth_rev->execute($revid) || die $dbh->errstr;
    my $row = $sth_rev->fetchrow_hashref();
    die "No metadata for p=$pageid,r=$revid" if !defined $row;

    my $fh = IO::Zlib->new();
    $fh->open($file, "rb") || die "open: $!";
    my $text = join('', $fh->getlines());
    $fh->close();

    xmlEscape($text);
    foreach my $key (keys %$row) {
	xmlEscape($row->{$key});
    }
    my $ts = $$row{rev_timestamp};
    if ($ts =~ m/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/) {
	$$row{rev_timestamp}="$1-$2-$3T$4:$5:$6Z";
    } else {
	die "Bad timestamp: [$ts]";
    }

    my $outdir = OUTDIR . join("/", map { substr($pageid, $_, 3) } (0,3,6,9) );
    mkpath($outdir, { verbose => 1, mode => 0750 });
     
    my $destfile = $outdir . "/revisions.txt.gz";
    my $tmpfile = $outdir . "/.tmp.revs.txt.gz";

    my $meta = $outdir . "/meta.txt";

    if ($pageid != $last_pageid) {
	$last_cleanup->() if defined $last_cleanup;
	$last_pageid = $pageid;

	$sth_page->execute($pageid) || die $dbh->errstr;
	my $row = $sth_page->fetchrow_hashref();
	if (!defined $row) {
	    warn "No page metadata for p=$pageid,r=$revid";
	    $row = { page_title => '' };
	}

	# write meta data
	open(OUT, ">$meta") || die "open($meta): $!";
	print OUT $$row{page_title}, "\n";
	print OUT $pageid, "\n";
	close(OUT);

        die "Bad filehandle" if defined $last_tmp;
	$last_tmp = IO::Zlib->new($tmpfile, "wb9") || die "open($tmpfile): $!";

	# need to copy original revs first
	copy($destfile, $last_tmp);
	$last_cleanup = sub {
	    $last_tmp->close();
	    $last_tmp = undef;
	    #print "Moving $tmpfile\n\tto $destfile\n";
	    if (-e $destfile) {
		unlink($destfile) || die "unlink($destfile): $!";
	    }
	    link($tmpfile, $destfile) || die "link($tmpfile, $destfile): $!";
	    unlink($tmpfile) || die "unlink($tmpfile): $!";
	};
    }

    $last_tmp->print("    <revision>\n");
    $last_tmp->print("      <id>$revid</id>\n");
    $last_tmp->print("      <timestamp>$$row{rev_timestamp}</timestamp>\n");
    $last_tmp->print("      <contributor>\n");
    if ($$row{rev_user_text} =~ m/^\d+\.\d+\.\d+\.\d+$/) {
	$last_tmp->print("        <ip>$$row{rev_user_text}</ip>\n");
    } else {
	$last_tmp->print("        <username>$$row{rev_user_text}</username>\n");
	$last_tmp->print("        <id>$$row{rev_user}</id>\n");
    }
    $last_tmp->print("      </contributor>\n");
    $last_tmp->print("      <comment>$$row{rev_comment}</comment>\n");
    $last_tmp->print("      <text xml:space=\"preserve\">$text</text>\n");
    $last_tmp->print("    </revision>\n");

#print "Appended to $tmpfile\n";
}

sub copy {
    my ($srcfile, $outfh) = @_;

    return if !-e $srcfile;
    my $infh = IO::Zlib->new();
    $infh->open($srcfile, "rb") || die "open: $!";
    while (!$infh->eof()) {
	my $line = $infh->getline();
	last if !defined $line;
	$outfh->print($line);
    }
    $infh->close();
}

sub xmlEscape {
    $_[0] =~ s/\&/&amp;/g;
    $_[0] =~ s/\"/&quot;/g;
    $_[0] =~ s/\</&lt;/g;
    $_[0] =~ s/\>/&gt;/g;
    return $_[0];
}

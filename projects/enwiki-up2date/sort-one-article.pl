#!/usr/bin/perl

# Go through article files and revisions by (timestamp, revid)

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";

use IO::Handle;
use File::Find;
use Data::Dumper;
use XML::Simple;
use Encode;
use Error qw(:try);

use Carp;
use DB_File;
use IO::Select;
use File::Path qw(mkpath);
use Storable qw(store_fd fd_retrieve);


my $outdir = shift @ARGV;
my $pageid = shift @ARGV;

sortArticle($pageid);
exit(0);

sub sortArticle {
    my $pageid = shift @_;
    my $file = getOutfile($pageid);

    open(my $gz, "gunzip -c $file |") || die "open($file): $!";
    binmode $gz, ":bytes";
    my (@recs, %revidSeen);
    while (my $revxml = getRevision($gz, $file)) {
	$revxml->{id} =~ s/^0+//;
	my $revid = $revxml->{id};
	die "Bad revid:[$revid]" if !defined $revid;
	next if $revidSeen{$revid};
	$revidSeen{$revid} = 1;
	push @recs, $revxml;
    }
    $gz->close();

    if (@recs > 0) {
	@recs = sort sortByTimeRev @recs;
	my $tmp = $file.".tmp";
	open(my $out, "| gzip -c > $tmp") || die "open($tmp): $!";
	foreach my $revxml (@recs) {
	    printRevision($out, $revxml);
	}
	$out->close();
	unlink($file);
	rename($tmp, $file) || die "rename($tmp): $!";
    }
}

sub getOutfile {
    my $pageid = shift @_;
    my $longid = sprintf("%012d", $pageid);
    my $outfiledir = $outdir
	.'/'. join("/", map { substr($longid, $_, 3) } (0,3,6) );
    mkpath($outfiledir, { verbose => 0, mode => 0750 }) if !-d $outfiledir;
    my $outfile = $outfiledir . "/" . $longid . ".gz";
    return $outfile;
}

sub sortByTimeRev {
    if ($a->{timestamp} eq $b->{timestamp}) {
	return ($a->{id} <=> $b->{id})
    }
    return ($a->{timestamp} cmp $b->{timestamp});
}

sub getRevision {
    my ($fh, $file) = @_;
    return undef if $fh->eof();
    local $/ = '</revision>';
    my $data = $fh->getline();
    $data =~ s#<restrictions>.*?</restrictions>##;
    return undef if $data =~ m/^\s*$/;
    my $xml = undef;
    try {
	$xml = XMLin($data);
    } otherwise {
	my $E = shift;
	warn "ERROR in file: $file\n";
	warn "Troubled input: [[$data]]\n\n";
	die $E;
    };
    return $xml;
}


sub printRevision {
    my ($fh, $obj) = @_;

confess "No id" if !exists $obj->{id};
confess "Bad id" if $obj->{id} eq '';

    my $data = "";
    $data .="    <revision>\n";
    $data .="      <id>". xmlEscape($obj->{id}). "</id>\n";
    $data .="      <timestamp>". xmlEscape($obj->{timestamp}). "</timestamp>\n";
    $data .="      <contributor>\n";
    if (exists $obj->{contributor}->{ip}) {
	$data .="        <ip>". xmlEscape($obj->{contributor}->{ip}). "</ip>\n";
    } else {
	$data .="        <username>". xmlEscape($obj->{contributor}->{username}). "</username>\n";
	$data .="        <id>". xmlEscape($obj->{contributor}->{id}). "</id>\n";
    }
    $data .="      </contributor>\n";
    $data .="      <comment>". xmlEscape($obj->{comment}). "</comment>\n" if exists $obj->{comment};
    my $text = $obj->{text}->{content} || '';
    $data .="      <text xml:space=\"preserve\">". xmlEscape($text) . "</text>\n";
    $data .="    </revision>\n";
    $fh->print($data);
}

sub xmlEscape {
    $_[0] =~ s/\&/&amp;/g;
    $_[0] =~ s/\"/&quot;/g;
    $_[0] =~ s/\</&lt;/g;
    $_[0] =~ s/\>/&gt;/g;
    return $_[0];
}


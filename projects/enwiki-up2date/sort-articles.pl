#!/usr/bin/perl

# Go through article files and revisions by (timestamp, revid)

use constant OUTDIR => "./ensplit-20080103/";

use File::Find;
use IO::Zlib;
use Data::Dumper;
use File::Path qw(mkpath);
use XML::Simple;

find({ wanted => \&wanted, no_chdir=>1 }, SRCDIR);
exit(0);

sub wanted {
    my $file = $File::Find::name;
    next if -d $file;
    my $fh = IO::Zlib->new();
    $fh->open($file, "rb") || die "open: $!";
    my (@recs, %revidSeen);
    while (my $revxml = getRevision($fh)) {
	print Dumper($revxml);
	exit(0);
	my $revid = $revxml->{id};
	next if $revidSeen{$revid};
	$revidSeen{$revid} = 1;
	push @recs, $revxml;
    }
    $fh->close();
    if (@recs > 0) {
	@recs = sort sortByTimeRev @recs;
#	unlink($file) || die "unlink($file): $!";
	$fh = IO::Zlib->new($file, "wb9") || die "open($file): $!";
	foreach my $revxml (@recs) {
	    my $xml = XMLout($revxml);
print $xml;
exit(0);
	}
	$fh->close();
    }
}

sub sortByTimeRev {
    if ($a->{timestamp} eq $b->{timestamp}) {
	return ($a->{id} <=> $b->{id})
    }
    return ($a->{timestamp} <=> $b->{timestamp});
}

sub getRevision {
    my $fh = shift @_;
    return undef if $fh->eof();
    my $line;
    my $data = '';
    do {
	$line = $fh->getline();
	$data .= $line;
    } while (!$fh->eof() && $line !~ m/<(\/revision)>/);
    return undef if $data =~ m/^\s*$/;
    my $xml = XMLin($data);
    return $xml;
}


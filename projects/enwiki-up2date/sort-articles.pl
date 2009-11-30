#!/usr/bin/perl

# Go through article files and revisions by (timestamp, revid)

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";

use constant OUTDIR => "./ensplit-20080103/";

use File::Find;
use IO::Zlib;
use Data::Dumper;
use File::Path qw(mkpath);
use XML::Simple;
use Encode;
use Error qw(:try);

binmode STDOUT, ":utf8";
find({ wanted => \&wanted, no_chdir=>1 }, OUTDIR);
exit(0);

sub wanted {
    my $file = $File::Find::name;
    return if -d $file;
    return if $file !~ m/\.gz$/;
print "FILE [$file]\n";
    my $fh = IO::Zlib->new();
    $fh->open($file, "rb") || die "open: $!";
    my (@recs, %revidSeen);
    while (my $revxml = getRevision($fh, $file)) {
	my $revid = $revxml->{id};
	die "Bad revid:[$revid]" if !defined $revid;
	next if $revidSeen{$revid};
	$revidSeen{$revid} = 1;
	push @recs, $revxml;
    }
    $fh->close();
    if (@recs > 0) {
print "Sorting recs...\n";
	@recs = sort sortByTimeRev @recs;
	$fh = IO::Zlib->new($file.".tmp", "wb9") || die "open($file): $!";
	foreach my $revxml (@recs) {
	    printRevision($fh, $revxml);
	}
	$fh->close();
	unlink($file) || die "unlink($file): $!";
	rename($file.".tmp", $file) || die "rename($file): $!";
    }
print "Done with $file\n";
}

sub sortByTimeRev {
    if ($a->{timestamp} eq $b->{timestamp}) {
	return ($a->{id} <=> $b->{id})
    }
    return ($a->{timestamp} cmp $b->{timestamp});
}

sub getRevision {
    my $fh = shift @_;
    my $file = shift @_;
    return undef if $fh->eof();
    my $line;
    my $data = '';
    do {
	$line = $fh->getline();
	$data .= $line if defined $line;
    } while (!$fh->eof() && $line !~ m/<(\/revision)>/);
    return undef if $data =~ m/^\s*$/;
    my $xml = undef;
    my $cleanup = sub {
	my ($open, $close) = @_;
	my $first = index($data, $open);
	return if $first < 0;
	$first += length($open);
	my $last = rindex($data, $close);
	substr($data, $first, $last-$first) =~ s/\&/&amp;/g;
	$last = rindex($data, $close);
	substr($data, $first, $last-$first) =~ s/\"/&quot;/g;
	$last = rindex($data, $close);
	substr($data, $first, $last-$first) =~ s/\</&lt;/g;
	$last = rindex($data, $close);
	substr($data, $first, $last-$first) =~ s/\>/&gt;/g;
    };
    try {
	$cleanup->('<text xml:space="preserve">', '</text>');
	$cleanup->('<comment>', '</comment>');
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
    my $fh = shift @_;
    my $obj = shift @_;

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
    $fh->print(Encode::encode_utf8($data));
}

sub xmlEscape {
    $_[0] =~ s/\&/&amp;/g;
    $_[0] =~ s/\"/&quot;/g;
    $_[0] =~ s/\</&lt;/g;
    $_[0] =~ s/\>/&gt;/g;
}


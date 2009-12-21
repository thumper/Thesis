#!/usr/bin/perl

# Go through article files and revisions by (timestamp, revid)

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";

use constant OUTDIR => "./ensplit4-20080103.mmap/";

use IO::Handle;
use File::Find;
use Data::Dumper;
use XML::Simple;
use Encode;
use Error qw(:try);

my $subprocesses = 0;

binmode STDOUT, ":utf8";
find({ wanted => \&wanted, no_chdir=>1 }, OUTDIR);
while ($subprocesses > 0) {
warn "Waiting on $subprocesses children";
    my $kid = waitpid(-1, 0);
    die "bad kid: $kid" if $kid < 0;
    die "child died badly: $?" if $? != 0;
    $subprocesses--;
}
exit(0);

sub wanted {
    my $file = $File::Find::name;
    return if -d $file;
    return if $file !~ m/\.bz2$/;
print "FILE [$file]\n";
    while ($subprocesses > 8) {
	my $kid = waitpid(-1, 0);
	die "bad kid: $kid" if $kid < 0;
	die "child died badly: $?" if $? != 0;
	$subprocesses--;
    }
    $subprocesses++;
    return if fork();		# return in parent

    open(my $fh, "pbzip2 -d -c -q $file |") || die "open($file): $!";
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
	@recs = sort sortByTimeRev @recs;
	open(my $out, "| pbzip2 -9 -q -c > $file.tmp") || die "open($file.tmp): $!";
	foreach my $revxml (@recs) {
	    printRevision($out, $revxml);
	}
	$out->close();
	unlink($file) || die "unlink($file): $!";
	rename($file.".tmp", $file) || die "rename($file): $!";
    }
    exit(0);
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
    try {
	#$data =~ s/\x{EFBF}/\?/g;
$data =~ s/\x{EF}\x{BF}/\?/g;
#if (length($data) > 500) {
#my $c = ord(substr($data, 458, 1));
#warn "char @ 458 = $c" if $c > 127;
#$c = ord(substr($data, 457, 1));
#warn "char @ 457 = $c" if $c > 127;
#$c = ord(substr($data, 459, 1));
#warn "char @ 459 = $c" if $c > 127;
#}
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


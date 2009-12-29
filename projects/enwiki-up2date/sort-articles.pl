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


my $indir = shift @ARGV;
my $outdir = shift @ARGV;
my %lastrevid;
tie %lastrevid, 'DB_File', 'lastrev.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;

my @subprocesses;

binmode STDOUT, ":utf8";
find({ wanted => \&wanted, no_chdir=>1 }, $indir);
while (@subprocesses > 0) { waitForChildren(); }
untie(%lastrevid);
exit(0);

sub waitForChildren {
    my $s = IO::Select->new(@subprocesses);

    my @ready = $s->can_read(10);
    foreach my $fh (@ready) {
	my $hash = fd_retrieve($fh) || die "can't read $fh";
	while (my ($pageid, $newlast) = each %$hash) {
	    $lastrevid{$pageid} = $newlast;
	}
	$fh->close();
	@subprocesses = grep { $_ != $fh } @subprocesses;
    }
}


sub wanted {
    my $file = $File::Find::name;
    return if -d $file;
    return if $file !~ m/\.gz$/;

    my $longid = $file;
    $longid =~ s#.*/##;
    $longid =~ s#\.gz##;
    die "Bad pageid[$file -> $longid]" if length($longid) != 12;
    my $pageid = $longid;
    $pageid =~ s/^0+//;

    while (@subprocesses > 20) { waitForChildren(); }
print "FILE [$file]\n";
    # TODO: need to untie hash before fork!
    my $pid = open my $fh, "-|";
    die unless defined $pid;
    if ($pid) {
	push @subprocesses, $fh;
	return;		# return in parent
    }

    open(my $gz, "gunzip -c $file |") || die "open($file): $!";
    my (@recs, %revidSeen, $lastrevid);
    while (my $revxml = getRevision($gz, $file)) {
	$revxml->{id} =~ s/^0+//;
	my $revid = $revxml->{id};
	die "Bad revid:[$revid]" if !defined $revid;
	next if $revidSeen{$revid};
	$lastrevid = $revid if (defined $revid) || ($revid > $lastrevid);
	$revidSeen{$revid} = 1;
	push @recs, $revxml;
    }
    $gz->close();

    if (@recs > 0) {
	my $outfile = getOutfile($longid);
	@recs = sort sortByTimeRev @recs;
	my $tmp = $outfile.".tmp";
	open(my $out, "| gzip -c > $tmp") || die "open($tmp): $!";
	foreach my $revxml (@recs) {
	    printRevision($out, $revxml);
	}
	$out->close();
	unlink($outfile);
	rename($tmp, $outfile) || die "rename($tmp): $!";
    }

    my $lastrev = { $pageid => $lastrevid };
#    print "Here comes the data.\n";
#    print "DATA\n";
    store_fd($lastrev, \*STDOUT) || die "can't store result";

    exit(0);
}

sub getOutfile {
    my $longid = shift @_;
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
    my $line;
    my $data = '';
    do {
	$line = $fh->getline();
	$data .= $line if defined $line && $line !~ m/<restrictions>/;
    } while (!$fh->eof() && $line !~ m/<(\/revision)>/);
    return undef if $data =~ m/^\s*$/;
    my $xml = undef;
    try {
	$xml = XMLin($data);
    } otherwise {
	my $E = shift;
	warn "ERROR in file: $file\n";
	warn "Troubled input: [[$data]]\n\n";
	store_fd({}, \*STDOUT) || die "can't store result";
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


#!/usr/bin/perl

use strict;
use warnings;
use open IN => ":utf8", OUT => ":utf8";
use URI::Escape;
use LWP::Simple;
use JSON::XS;
use Data::Dumper;
use DB_File;
use File::Path qw(mkpath);
use Encode;
use Carp;
use IO::Select;
use Storable qw(store_fd fd_retrieve);
use XML::Simple;
use Error qw(:try);

use constant WIKIAPI => 'http://en.wikipedia.org/w/api.php';
use constant USERAPI => 'http://toolserver.org/~Ipye/UserName2UserId.php';

my $outdir = shift @ARGV;
my @subprocesses;
my (%lastrevid, %userid, %pageid);

while (<>) {
    chomp;
    my $title = $_;

    last if -f "stop.txt";
    while (@subprocesses > 4) { waitForChildren(); }

    tieHashes();
    my @args = getPageInfo($title);
    untieHashes();

    my $pid = open my $fh, "-|";
    die unless defined $pid;
    if ($pid) {
	push @subprocesses, $fh;
    } else {
	my $lastrevid = fetch_page(@args);
	my $pageid = $args[1];
	my $result = {
	    'pageid' => $pageid,
	    'lastrevid' => $lastrevid,
	    'userids' => \%userid,
	};
warn "$pageid: Storing lastrev = $lastrevid\n";
	store_fd($result, \*STDOUT) || die "can't store result";
	exit(0);
    }
}
while (@subprocesses > 0) { waitForChildren(); }
exit(0);

sub waitForChildren {
    my $s = IO::Select->new(@subprocesses);

    my @ready = $s->can_read(10);
    tieHashes();
    foreach my $fh (@ready) {
	my $result = fd_retrieve($fh) || die "can't read $fh";
	$fh->close();
	@subprocesses = grep { $_ != $fh } @subprocesses;

	while (my ($name, $userid) = each %{$result->{userids}}) {
	    $userid{$name} = $userid;
	}
	delete $result->{userids};
	my $pageid = $result->{pageid};
	$lastrevid{$pageid} = $result->{lastrevid};
warn "$pageid: lastrev = [".$result->{lastrevid}."]\n";
warn Dumper($result) if !defined $result->{lastrevid};
    }
    untieHashes();
}

sub tieHashes {
    tie %lastrevid, 'DB_File', 'lastrev.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
    tie %userid, 'DB_File', 'userid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
    tie %pageid, 'DB_File', 'pageid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
}

sub untieHashes {
    untie %pageid;
    untie %userid;
    untie %lastrevid;
}

sub getPageInfo {
    my ($title) = @_;
    my $pageid = getPageid($title);
    my $nextrev = getLastrevid($pageid);
    die "$pageid: Bad nextrev [$nextrev] for [$title]" if defined $nextrev && $nextrev eq '';
    return ($title, $pageid, $nextrev);
}

sub fetch_page {
    my ($title, $pageid, $nextrev) = @_;

    if (!defined $nextrev) {
	my $file = getOutfile($pageid);
	die "$pageid: No file [$file]" if !-f $file;
	my ($lastrev, $recs) = readRecords($pageid);
	$nextrev = $lastrev;
    }
    die "$pageid: No nextrev" if !defined $nextrev;

    my $lastrevid = $nextrev;
    my $page;
    do {
	warn "$pageid: Working on rev $nextrev of title $title\n";
	($page, $nextrev) = download_page(titlerevs_selector($title, $nextrev));
	$lastrevid = saveRevisions($page, $lastrevid);
die "$pageid: Bad lastrev" if !defined $lastrevid;
    } while (defined $nextrev);
    return $lastrevid;
}



sub titlerevs_selector {
    my ($title, $revid, $limit) = @_;
    $limit ||= 50;

    return "titles=".uri_escape($title).
	"&prop=revisions|info".
        "&inprop=&rvprop=ids|flags|timestamp|user|size|comment|content".
	"&rvdir=newer".
	"&rvstartid=".$revid.
	"&rvlimit=".$limit;
}

sub titleinfo_selector {
    my ($title) = @_;

    return "titles=".uri_escape($title).
	"&prop=info";
}

sub getPageid {
    my $title = shift @_;
    return $pageid{$title} if exists $pageid{$title};

    my ($page, $nextid) = download_page(titleinfo_selector($title));
    my $pageid = $page->{pageid};
    if (!$pageid) {
	warn Dumper($page);
	die "No pageid for [$title]";
    }
    $pageid =~ s/^0+//;

    $pageid{$title} = $pageid;
    return $pageid;
}

sub download_page {
    my $selector = shift @_;
    my $url = WIKIAPI.
       "?action=query&format=json&".
       $selector;

    my $content = get $url;
    my $json = JSON::XS->new;
    $json->ascii(0);
    $json->utf8(0);
    $json->latin1(0);
    my $data = $json->decode($content);

    my @pageids = keys %{$data->{query}->{pages}};
    die "Wrong number of pageids" if @pageids != 1;
    my $key = shift @pageids;
    die "API raised error -1" if $key == -1;
    my $page = $data->{query}->{pages}->{$key};

    return (undef, undef) if $page->{ns} != 0;
    my $nextrev = $data->{"query-continue"}->{revisions}->{rvstartid};
    return ($page, $nextrev);
}

sub saveRevisions {
    my ($page, $lastrevid) = @_;

    my $pageid = $page->{pageid} || die "No pageid defined";

    my $revs = $page->{revisions};
    my $newrevs = 0;
    foreach my $rev (@$revs) {
	if ($rev->{revid} > $lastrevid) {
	    $newrevs++;
	    $lastrevid = $rev->{revid};
	};
    }

    return $lastrevid if $newrevs < 1;

    my $file = getOutfile($pageid);

    open(my $out, "| gzip --best -c >> $file") || die "open($file): $!";
    foreach my $rev (@$revs) {
	my $text = $rev->{'*'};
	$$rev{user} = '256.256.256.256' if !exists $$rev{user};
	my $contrib = '';
	if ($$rev{user} =~ m/^\d+\.\d+\.\d+\.\d+$/) {
	    $contrib = "        <ip>$$rev{user}</ip>\n";
	} else {
	    my $userid = getUserid($rev->{user});
	    $contrib = "        <username>".xmlEscape($$rev{user})."</username>\n"
		    ."        <id>$userid</id>\n";
	}
	$out->print("    <revision>\n");
	$out->print("      <id>$$rev{revid}</id>\n");
	$out->print("      <timestamp>$$rev{timestamp}</timestamp>\n");
	$out->print("      <contributor>\n");
	$out->print($contrib);
	$out->print("      </contributor>\n");
	$out->print("      <comment>".xmlEscape($$rev{comment})."</comment>\n") if exists $$rev{comment};
	$out->print("      <text xml:space=\"preserve\">".xmlEscape($text)."</text>\n");
	$out->print("    </revision>\n");
    }
    close($file);

    return $lastrevid;
}

sub getOutfile {
    my $pageid = shift @_;
    my $longid = sprintf("%012d", $pageid);

    my $outdir = $outdir ."/". join("/", map { substr($longid, $_, 3) } (0,3,6) );
    mkpath($outdir, { verbose => 0, mode => 0750 });

    my $file = $outdir . "/" . $longid . ".gz";
    return $file;
}

sub getUserid {
    my $name = shift @_;
    my $utf8name = encode_utf8($name);
    return $userid{$utf8name} if exists $userid{$utf8name};

    my %userid2;
    tie %userid2, 'DB_File', 'userid.db', O_RDONLY, 0644, $DB_BTREE;
    my $uid = $userid2{$utf8name};
    untie(%userid2);
    if (defined $uid) {
	# cache result away
	$userid{$utf8name} = $uid;
	return $uid;
    }

    my $tries = 0;
    my $url = USERAPI . "?n=".uri_escape($utf8name);
    while ($tries < 5) {
	my $userid = get $url;
	if (defined $userid) {
	    $userid =~ s/\`//g;
	    $userid{$utf8name} = $userid;
	    return $userid;
	}
	$tries++;
	sleep(120);
    }
    die "url[$url]\nUnable to find userid for [$utf8name]" if !defined $userid;
}

sub getLastrevid {
    my $pageid = shift @_ || confess "No pageid set";
    my $lastrevid = $lastrevid{$pageid};
    return $lastrevid{$pageid} if defined $lastrevid && $lastrevid ne '';

    my $file = getOutfile($pageid);
    return undef if -f $file;

    $lastrevid{$pageid} = 0;
    return 0;
}

sub xmlEscape {
    $_[0] =~ s/\&/&amp;/g;
    $_[0] =~ s/\"/&quot;/g;
    $_[0] =~ s/\</&lt;/g;
    $_[0] =~ s/\>/&gt;/g;
    return $_[0];
}

sub readRecords {
    my ($pageid) = @_;
    my $file = getOutfile($pageid);

    open(my $gz, "gunzip -c $file |") || die "open($file): $!";
    local $/ = '</revision>';
    binmode $gz, ":bytes";
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

    return ($lastrevid, \@recs);
}

sub writeRecords {
    my ($pageid, $recs) = @_;
    my $file = getOutfile($pageid);
    @$recs = sort sortByTimeRev @$recs;
    my $tmp = $file.".tmp";
    open(my $out, "| gzip -c > $tmp") || die "open($tmp): $!";
    foreach my $revxml (@$recs) {
	printRevision($out, $revxml);
    }
    $out->close();
    unlink($file);
    rename($tmp, $file) || die "rename($tmp): $!";
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
    my $data = <$fh>;
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

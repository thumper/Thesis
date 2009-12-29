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

use constant WIKIAPI => 'http://en.wikipedia.org/w/api.php';
use constant USERAPI => 'http://toolserver.org/~Ipye/UserName2UserId.php';

my $outdir = shift @ARGV;
my (%lastrevid, %userid, %pageid);
tie %lastrevid, 'DB_File', 'lastrev.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
tie %userid, 'DB_File', 'userid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
tie %pageid, 'DB_File', 'pageid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;

while (<>) {
    chomp;
    fetch_page($_);
    last if -f "stop.txt";
}
untie %pageid;
untie %userid;
untie %lastrevid;
exit(0);

sub fetch_page {
    my $title = shift @_;

    my $pageid = getPageid($title);
    my $nextrev = getLastrevid($pageid);
    my $page;
    do {
	print "$pageid: Working on rev $nextrev of title $title\n";
	($page, $nextrev) = download_page(titlerevs_selector($title, $nextrev));
	saveRevisions($page);
    } while (defined $nextrev);
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
    my ($page) = @_;

    my $pageid = $page->{pageid} || die "No pageid defined";

    my $revs = $page->{revisions};
    my $newrevs = 0;
    my $lastrevid = $lastrevid{$pageid};
    foreach my $rev (@$revs) {
	if ($rev->{revid} > $lastrevid) {
	    $newrevs++;
	    $lastrevid = $rev->{revid};
	};
    }

    return if $newrevs < 1;

    my $longid = sprintf("%012d", $pageid);

    my $outdir = $outdir ."/". join("/", map { substr($longid, $_, 3) } (0,3,6) );
    mkpath($outdir, { verbose => 1, mode => 0750 });

    my $file = $outdir . "/" . $longid . ".gz";

    open(my $out, "| gzip --best -c >> $file") || die "open($file): $!";
    foreach my $rev (@$revs) {
	my $text = $rev->{'*'};
	$out->print("    <revision>\n");
	$out->print("      <id>$$rev{revid}</id>\n");
	$out->print("      <timestamp>$$rev{timestamp}</timestamp>\n");
	$out->print("      <contributor>\n");
	if ($$rev{user} =~ m/^\d+\.\d+\.\d+\.\d+$/) {
	    $out->print("        <ip>$$rev{user}</ip>\n");
	} else {
	    my $userid = getUserid($rev->{user});
	    $out->print("        <username>".xmlEscape($$rev{user})."</username>\n");
	    $out->print("        <id>$userid</id>\n");
	}
	$out->print("      </contributor>\n");
	$out->print("      <comment>".xmlEscape($$rev{comment})."</comment>\n") if exists $$rev{comment};
	$out->print("      <text xml:space=\"preserve\">".xmlEscape($text)."</text>\n");
	$out->print("    </revision>\n");
    }
    close($file);

    $lastrevid{$pageid} = $lastrevid;
}

sub getUserid {
    my $name = shift @_;
    my $utf8name = encode_utf8($name);
    return $userid{$utf8name} if exists $userid{$utf8name};

    my $url = USERAPI . "?n=".uri_escape($utf8name);
    my $userid = get $url;
    die "Unable to find userid for [$utf8name]" if !defined $userid;
    $userid =~ s/\`//g;
    $userid{$utf8name} = $userid;
    return $userid;
}

sub getLastrevid {
    my $pageid = shift @_ || confess "No pageid set";
    return $lastrevid{$pageid} if exists $lastrevid{$pageid};
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

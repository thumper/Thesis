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
use Carp;

use constant WIKIAPI => 'http://en.wikipedia.org/w/api.php';
use constant USERAPI => 'http://toolserver.org/~Ipye/UserName2UserId.php';

my $outdir = shift @ARGV;
my (%lastrevid, %userid, %pageid);
tie %lastrevid, 'DB_File', 'lastrev.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
tie %userid, 'DB_File', 'userid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
tie %pageid, 'DB_File', 'pageid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;

    #fetch_page(title_selector('Main_Page', 333503364));
   fetch_page('Anguilla');
   # fetch_page(title_selector('Copenhagen', 333503364));
   # fetch_page(title_selector('Copenhagen', 33350));
untie %pageid;
untie %userid;
untie %lastrevid;
exit(0);
while (<>) {
    chomp;
    fetch_page($_);
}
exit(0);

sub fetch_page {
    my $title = shift @_;

    my $pageid = getPageid($title);
    my $nextrev = getLastrevid($pageid);
    my $page;
    do {
	print "Working on rev $nextrev\n";
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
    foreach my $rev (@$revs) {
	if ($rev->{revid} > $lastrevid{$pageid}) {
	    $newrevs++;
	    $lastrevid{$pageid} = $rev->{revid};
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
}

sub getUserid {
    my $name = shift @_;
    return $userid{$name} if exists $userid{$name};

    my $url = USERAPI . "?n=".uri_escape($name);
    my $userid = get $url;
    $userid =~ s/\`//g;
    $userid{$name} = $userid;
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

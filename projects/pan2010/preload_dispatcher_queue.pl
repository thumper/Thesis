#!/usr/bin/perl

#
# Copyright (c) 2010 B. Thomas Adler
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# 3. The names of the contributors may not be used to endorse or promote
# products derived from this software without specific prior written
# permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

use strict;
use warnings;
use open qw(:std :utf8);
use constant DB_ENGINE => "mysql";
use constant BASE_DIR => "./";
use constant INI_FILE => BASE_DIR . "db_access_data.ini";

use constant TRY_EASY => 1;
use constant TRY_WEBPID => 1;
use constant DELETE_PAGE => 0;
use constant COLOR_PAGE => 1;

use Text::ParseWords;
use DBI;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use URI::Escape;
use lib '/home/wikitrust/perl';
use WikiTrust;

my %db = readINI(INI_FILE);

my $dbname = join(':', "DBI", DB_ENGINE,
	"database=".$db{db},
	"host=".$db{host});

my $dbh = DBI->connect($dbname, $db{user}, $db{pass},
	{ RaiseError => 1, AutoCommit => 1 });

my (%erased, %alreadybad);

my $sth_pid = $dbh->prepare('SELECT page_id FROM page WHERE page_title = ?');
my $sth_rid = $dbh->prepare('SELECT revision_id FROM wikitrust_revision WHERE revision_id = ?');

my ($revcol, $titlecol, $diffcol, $pagecol);

while (<>) {
    chomp;
    my @f = quotewords ',', 0, $_;
    if ($f[0] eq 'editid' || $f[0] eq 'editor') {
	for (my $i = 0; $i < @f; $i++) {
	    $revcol = $i if $f[$i] eq 'newrevisionid';
	    $titlecol = $i if $f[$i] eq 'articletitle';
	    $diffcol = $i if $f[$i] eq 'diffurl';
	    $pagecol = $i if $f[$i] eq 'articleid';
	}
	next;
    }
    my $rev = $f[$revcol];
    do {
	$sth_rid->execute($rev) || die "Couldn't execute: ".$sth_rid->errstr;
	my @data = $sth_rid->fetchrow_array();
	next if @data > 0;
    };
    my $title = $f[$titlecol];
    next if exists $alreadybad{$title};

    my ($pageid, $source);
    if (defined $pagecol) {
	$pageid = $f[$pagecol];
	$source = 'CSV';
    }

    if (TRY_EASY && !defined $pageid) {
	$sth_pid->execute($title) || die "Couldn't execute: ".$sth_pid->errstr;
	my @data = $sth_pid->fetchrow_array();
	if (@data > 0) {
	    if (!defined $pageid || $pageid != $data[0]) {
		$pageid = $data[0];
		$source = 'DB';
	    }
	}
    }
    if (TRY_WEBPID || !defined $pageid) {
	# Let's try to get it via the web
	my $url = $f[$diffcol];
#warn "Getting url for $title\n";
#warn "$url\n";
	my $ua = LWP::UserAgent->new;
	$ua->agent('Mozilla/4.0 (compatible; MSIE 5.0; Windows 95)');

	my $req = GET $url;
	my $res = $ua->request($req);
	die $res->status_line if !$res->is_success;
	my $pagedata = $res->decoded_content;
die "no data" if !defined $pagedata;
	if ($pagedata =~ m/\bwgArticleId=(\d+),/) {
	    if (!defined $pageid || $pageid != $1) {
		$pageid = $1;
		$source = 'WEB';
	    }
	} else {
	    warn "Bad url: $url\n";
	    next;
	}
	if ($pagedata !~ m/\bwgNamespaceNumber=0,/) {
	    warn "Wrong namespace: $title\n";
	    $alreadybad{$title} = 1;
	    next;
	}
	# note: do not check for wgIsArticle=true ; on diffs, might be false
	if ($pagedata =~ m/\bmw\-missing\-article\b/) {
	    warn "Missing article: $title\n";
	    $alreadybad{$title} = 1;
	    next;
	}
    }
    if (!defined $pageid) {
#	warn "No pageid for \"$title\"";
	    print "$title\n";
    } else {
	DELETE_PAGE && delete_page($pageid, $title, $rev, $source);
	if (!DELETE_PAGE && COLOR_PAGE) {
	    my $url = $f[$diffcol];
	    warn "Coloring pageid $pageid, \"$title\": $url" if DELETE_PAGE;
	    WikiTrust::mark_for_coloring($pageid, $title, $dbh, 15);
	}
    }
}
exit(0);

sub delete_page {
    my $pageid = shift @_;
    my $title = shift @_;
    my $revid = shift @_;
    my $source = shift @_;

    return if exists $erased{$pageid};
    $erased{$pageid} = 1;

    warn "Deleting [$revid] $pageid (@ $source): $title\n";

    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 5.0; Windows 95)');

    my $url = "http://en.collaborativetrust.com/WikiTrust/RemoteAPI?method=delete&pageid=$pageid&&title=XXX&secret=Zup3rZ3kret&priority=15";

    my $req = GET $url;
    my $res = $ua->request($req);
    die $res->status_line if !$res->is_success;
    my $pagedata = $res->decoded_content;

    print "Deleted page $pageid: response=$pagedata\n";
    die "bad response" if $pagedata =~ m/error/;
}


sub readINI {
    my $ini = shift @_;
    my (%values);
    open(INI, "<$ini") || die "open($ini): $!";
    while (<INI>) {
	chomp;
	next if m/^\s*\[/;
	if (m/^\W*(\w+)\s*=\s*(\w+)\W*(#.*)?$/) {
	    $values{$1} = $2;
	}
    }
    close(INI);
    return %values;
}

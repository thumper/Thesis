#!/usr/bin/perl

# Copyright (c) 2010 The Regents of the University of California
# All rights reserved.
# 
# Authors: Bo Adler
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

# This program uses the WpAPI to discover recent changes and add them
# to the dispatcher queue.  It uses a file in /tmp to track the last
# timestamp received, which is used in the next run to get newer changes.
#
# ./GetWikiFeed.pl en enwikidb <dbuser> <dbpass>
#

use constant API_URL => ".wikipedia.org/w/api.php?action=query&format=json"
	."&list=recentchanges&rcprop=ids|timestamp"
	."&rclimit=1&rcdir=newer&rctype=edit|new"
	."&rcnamespace=0";
use constant TS_URL => "http://toolserver.org/~ipye/GetNewTitles.php?";
use constant LAST_REV_FILE => "/tmp/GetFeedFToolserver.txt-";
use constant DB_ENGINE => "mysql";

use strict;
use warnings;

use JSON;
use HTTP::Request::Common qw(GET);
use LWP::UserAgent;
use lib '.';
use WikiTrust;
use Data::Dumper;

die "Usage: $0 <lang> <dbname> <dbuser> <dbpass>\n" if @ARGV != 4;

my $lang = shift @ARGV || 'en';
my $dbname = shift @ARGV || '';
my $dbuser = shift @ARGV || '';
my $dbpass = shift @ARGV || '';

my $dbh = getDatabaseHandle($dbname, $dbuser, $dbpass);

my $curRev = getCurRev($lang);
my $lastRev = getLastRev($lang);
print "Continuing from $lastRev\n";

my $url = "http://".TS_URL."db=${lang}wiki&n=$lastRev";
my $req = GET $url;
my $ua = LWP::UserAgent->new;
$ua->agent('Mozilla/4.0 (compatible; MSIE 5.0; Windows 95)');
my $res = $ua->request($req);
die $res->status_line if !$res->is_success;
my $data = decode_json($res->decoded_content);
print Dumper($data) if $nextDate eq $lastDate;
exit(0);
my $count = 0;
foreach my $record (@{$data->{query}->{recentchanges}}) {
    my $pageid = $record->{pageid} || 0;
    my $timestamp = $record->{timestamp} || '';
    next if $pageid == 0;
    WikiTrust::mark_for_coloring($pageid, "XX-GetWikiFeed.pl", $dbh, 1);
    $count++;
}
print "Writing $curRev after $count records.\n";
writeLastRev($lang, $curRev);

exit(0);

sub getLastRev {
    my $lang = shift @_;
    return getCurRev() if !-e LAST_REV_FILE.$lang;
    open(INPUT, "<", LAST_REV_FILE.$lang) || die "open(LAST_REV): $!";
    my $data = <INPUT>;
    chomp($data);
    close(INPUT);
    return $data;
}

sub writeLastRev {
    my $lang = shift @_;
    my $data = shift @_;
    open(OUTPUT, ">", LAST_REV_FILE.$lang) || die "open(LAST_REV): $!";
    print OUTPUT "$data\n";
    close(OUTPUT);
}


sub getDatabaseHandle {
    my ($name, $user, $pass) = @_;
    my $dbname = join(':', "DBI", DB_ENGINE,
	"database=".$name, "host=localhost");

    my $dbh = DBI->connect($dbname, $user, $pass,
	{ RaiseError => 1, AutoCommit => 1 });
			     
    return $dbh;
}

sub getCurRev {
    my $lang = shift @_;
    my $url = "http://".$lang.BASE_URL;
    my $req = GET $url;
    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 5.0; Windows 95)');
    my $res = $ua->request($req);
    die $res->status_line if !$res->is_success;
    my $data = decode_json($res->decoded_content);
    my $revs = $data->{query}->{recentchanges};
    die "Bad revs from server: $url" if @$revs == 0;
    my $rev = pop @$revs;
    die "No revid: ".Dumper($rev) if !exists $rev->{revid};
    return $rev->{revid};
}


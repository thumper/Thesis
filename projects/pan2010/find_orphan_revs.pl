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

# Run this script to test all the revisions in table 'revision'
# to make sure that they've been processed and have the same pageid
# as in wikitrust_revision.  If not, delete the 'revision' pageid,
# and redownload.  (Most likely, the page got changed and the revision
# belongs to a different pageid.)

# This needs to be run while the dispatcher is off, so that revisions
# aren't "unprocessed" while this script is testing them.

use strict;
use warnings;
use open qw(:std :utf8);
use constant DB_ENGINE => "mysql";
use constant BASE_DIR => "./";
use constant INI_FILE => BASE_DIR . "db_access_data.ini";

use constant INCREMENT => 100000;
use constant START => 0; # 114180000;

use Text::ParseWords;
use DBI;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use URI::Escape;
use List::Util;
use lib '/home/wikitrust/perl';
use WikiTrust;

my %db = readINI(INI_FILE);

my $dbname = join(':', "DBI", DB_ENGINE, 
	"database=".$db{db},
	"host=".$db{host});

my $dbh = DBI->connect($dbname, $db{user}, $db{pass},
	{ RaiseError => 1, AutoCommit => 1 });

my %erased;

my $sth_revs = $dbh->prepare('SELECT rev_id,rev_page FROM revision WHERE rev_id >= ? and rev_id < ?');
my $sth_match = $dbh->prepare('SELECT page_id FROM wikitrust_revision WHERE revision_id = ?');


my $maxrid = findMax("revision", "rev_id");

my $rev_lower = 0;
while ($rev_lower <= $maxrid) {
    print "Working on $rev_lower out of $maxrid\n";
    $sth_revs->execute($rev_lower, $rev_lower+ INCREMENT)
	|| die "Couldn't execute: ".$sth_revs->errstr;
    while (my $data = $sth_revs->fetchrow_arrayref) {
	$sth_match->execute($data->[0]) || die "execute: ". $sth_match->errstr;
	my $match = $sth_match->fetchrow_arrayref;
	if (!defined $match) {
	    # Not in wikitrust, so probably orig page_id changed
	    delete_page($data->[1], 'XXX');
	} elsif ($data->[1] != $match->[0]) {
	    # Somehow, we got confused... delete both
	    delete_page($data->[1], 'XXX');
	    delete_page($match->[0], 'XXX');
	}
    }
    $rev_lower += INCREMENT;
}   
exit(0);

sub delete_page {
    my $pageid = shift @_;
    my $title = shift @_;

    return if exists $erased{$pageid};
    $erased{$pageid} = 1;

    warn "Deleting $pageid: $title\n";

    my $ua = LWP::UserAgent->new;
    $ua->agent('Mozilla/4.0 (compatible; MSIE 5.0; Windows 95)');
    $ua->timeout(300);

    my $url = "http://en.collaborativetrust.com/WikiTrust/RemoteAPI?method=delete&pageid=$pageid&&title=".uri_escape($title)."&secret=Zup3rZ3kret";

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

sub findMax {
    my ($table, $field) = @_;
    my $sth = $dbh->prepare("SELECT max($field) FROM $table");
    $sth->execute() || die "Couldn't execute: ".$sth->errstr;
    my @data = $sth->fetchrow_array();
    die "bad max($field) from $table" if @data == 0;
    return $data[0];
}


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

use constant SERVER => 'irc.wikimedia.org';
use constant DB_ENGINE => "mysql";

use strict;
use warnings;

use JSON;
use HTTP::Request::Common qw(GET);
use LWP::UserAgent;
use lib '/home/wikitrust/perl';
use WikiTrust;
use Data::Dumper;
use POE;
use POE::Component::IRC;

die "Usage: $0 <lang> <dbname> <dbuser> <dbpass>\n" if @ARGV != 4;

my $lang = shift @ARGV || 'en';
my $dbname = shift @ARGV || '';
my $dbuser = shift @ARGV || '';
my $dbpass = shift @ARGV || '';

my $dbh = getDatabaseHandle($dbname, $dbuser, $dbpass);
my $sth_pid = $dbh->prepare('SELECT page_id FROM page WHERE page_title = ?');

my $irc = POE::Component::IRC->spawn();

POE::Session->create(
    inline_states => {
	_start => \&bot_start,
	irc_001 => \&on_connect,
	irc_public => \&on_public,
    },
);

$poe_kernel->run();
exit(0);

sub bot_start {
    $irc->yield(register => "all");
    $irc->yield(
	connect => {
	    Nick => 'WikiTrustBot',
	    Username => 'wikitrustbot',
	    Ircname => 'WikiTrust Feed Bot',
	    Server => SERVER,
	    Port => 6667,
	}
    );
}

sub on_connect {
    $irc->yield(join => "#$lang.wikipedia");
}

sub on_public {
    my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
    my $nick = (split /!/, $who)[0];
    return if $nick ne 'rc-pmtpa';
    my $channel = $where->[0];
    $msg =~ s/\003..//g;
    if ($msg =~ m/\[\[(.*?)\]\]\s*(\S+)\b/) {
	my $title = $1;
	my $status = $2;
	return if $status eq 'create';
	return if $status eq 'delete';
	return if $status eq 'upload';
	return if $title =~ m/^(?:Talk|Wikipedia|Wikipedia talk):/;
	return if $title =~ m/^(?:Special|Special talk|User|User talk):/;
	return if $title =~ m/^(?:Template|Template talk|File|File talk):/;
	return if $title =~ m/^(?:Category|Category talk):/;
	$sth_pid->execute($title) || die "db err: ". $sth_pid->errstr;
	my @data = $sth_pid->fetchrow_array();
	if (@data > 0) {
	    my $pageid = $data[0];
	    WikiTrust::mark_for_coloring($pageid, "XX-GetIRCFeed.pl", $dbh, 1);
	} else {
	    print "Got title [[$title]] status=<$status>: $msg\n";
	    my @chars = split(//, $title);
	    foreach my $c (@chars) {
		printf "%02x $c\n", ord($c);
	    }
	}
    } else {
	    print "<$nick:$channel>\n";
	    print "$msg\n";
    }
}


sub getDatabaseHandle {
    my ($name, $user, $pass) = @_;
    my $dbname = join(':', "DBI", DB_ENGINE,
	"database=".$name, "host=localhost");

    my $dbh = DBI->connect($dbname, $user, $pass,
	{ RaiseError => 1, AutoCommit => 1 });
			     
    return $dbh;
}

__DATA__

my $count = 0;
foreach my $record (@{$data->{query}->{recentchanges}}) {
    my $pageid = $record->{pageid} || 0;
    my $timestamp = $record->{timestamp} || '';
    next if $pageid == 0;
    WikiTrust::mark_for_coloring($pageid, "XX-GetIRCFeed.pl", $dbh, 1);
    $nextDate = $timestamp if $timestamp gt $nextDate;
    $count++;
}
print "Writing $nextDate after $count records.\n";
writeLastDate($lang, $nextDate);



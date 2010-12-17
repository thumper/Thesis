#!/usr/bin/perl

use strict;
use warnings;

use lib '/home/wikitrust/perl';

use WikiTrust;
use DBI;
use constant BASE_DIR => "./";
use constant INI_FILE => BASE_DIR . "db_access_data.ini";
use constant DB_ENGINE => "mysql";


my %db = readINI(INI_FILE);

my $dbname = join(':', "DBI", DB_ENGINE, 
	"database=".$db{db},
	"host=".$db{host});

my $dbh = DBI->connect($dbname, $db{user}, $db{pass},
	{ RaiseError => 1, AutoCommit => 1 });

$ENV{WT_SECRET} = 'zekret';
$ENV{WT_DBNAME} = $dbname;
$ENV{WT_DBUSER} = $db{user};
$ENV{WT_DBPASS} = $db{pass};
$ENV{WT_BLOB_PATH} = "/giant/enwiki-20100130/blobs";

while (<>) {
    chomp;
    my ($revid, $pageid, $comment) = split(/\t/, $_, 3);

    $revid =~ s/ //g;
    if ($revid !~ m/^\d+$/) {
	warn "Bad revid: $_\n";
	next;
    };

    $pageid =~ s/ //g;
    if ($pageid !~ m/^\d*$/) {
	$pageid = '';
    } 
    $pageid = undef if $pageid eq '';

    $comment =~ s/^ +//;
    $comment =~ s/^\"//;
    $comment =~ s/\"$//;
    $comment =~ s/\\//;
    $comment = "" if $comment eq 'null';

    eval {
	my $q = WikiTrust::getQualityData('X X X', $pageid, $revid, $dbh);

	# the ZD model needs comment_len
if (0) {
	my $sth = $dbh->prepare ("SELECT rev_comment FROM "
		. "revision WHERE "
		. "rev_id = ? LIMIT 1") || die $dbh->errstr;
	$sth->execute($revid) || die $dbh->errstr;
	my $ans = $sth->fetchrow_hashref();
	if (defined $ans->{rev_comment}) {
	    $q->{Comment_len} = length($ans->{rev_comment});
	    warn "comment: ".$ans->{rev_comment}."\n";
	} else {
	    $q->{Comment_len} = 0;
	}
} else {
	$q->{Comment_len} = length($comment);
}

	my $prob = WikiTrust::vandalismZdModel($q);
	print "$revid\t$prob\n";
    };
    if ($@) {
	warn "$@\n";
    }
}
exit(0);


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

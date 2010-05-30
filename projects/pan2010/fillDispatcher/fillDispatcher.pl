#!/usr/bin/perl

use strict;
use warnings;

use WikiTrust;
use DBI;

my $dbname = shift @ARGV;
my $dbuser = shift @ARGV;
my $dbpass = shift @ARGV;

my $dbh = DBI->connect($dbname, $dbuser, $dbpass,
	{ RaiseError => 1, AutoCommit => 1 });


while (<>) {
    my ($pageid, $title) = split(/\t/, $_, 2);
    my $result = WikiTrust::mark_for_coloring($pageid, $title, $dbh);
}
exit(0);


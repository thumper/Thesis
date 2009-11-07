#!/usr/bin/perl

use strict;
use warnings;

my %page;

my (%statement);

header();

startTable('wikitrust_revision');
while (<>) {
    next if !m/^INSERT/;
    if (m/^INSERT INTO (\w+) (.*?) VALUES \((.*)\);/) {
	if (!defined $statement{$1}) {
	    $statement{$1} = "INSERT INTO $1 VALUES ($3)";
	} else {
	    $statement{$1} .= ",($3)";
	}
        if (length($statement{$1}) > 2*1024*1024) {
	    $statement{$1} .= ";\n";
	    if ($1 eq 'wikitrust_revision') {
		print $statement{$1};
	    } else {
		$page{$1} = [] if !defined $page{$1};
		push @{$page{$1}}, $statement{$1};
	    }
	    $statement{$1} = undef;
	}
    }
}
endTable('wikitrust_revision');

# use %statement, not %page, since 'wikitrust_revision'
# will only be in %statement
foreach my $table (keys %statement) {
    startTable($table);
    foreach my $s (@{$page{$table}}) {
	print $s;
    }
    if (defined $statement{$table}) {
	$statement{$table} .= ";\n";
	print $statement{$table};
    }
    endTable($table);
}

footer();

exit(0);

sub header {
    print <<'_END_';
-- MySQL dump 10.11
--
-- Host: localhost    Database: ptwikidb
-- ------------------------------------------------------
-- Server version       5.0.75-0ubuntu10.2

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

SET character_set_client = utf8;

_END_
}

sub footer {
    print <<'_END_';
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
_END_
}

sub startTable {
    my $table = shift @_;

    print <<_END_;
LOCK TABLES `$table` WRITE;
/*!40000 ALTER TABLE `$table` DISABLE KEYS */;
_END_
}
sub endTable {
    my $table = shift @_;

    print <<_END_;
/*!40000 ALTER TABLE `$table` ENABLE KEYS */;
UNLOCK TABLES;
_END_
}



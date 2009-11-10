#!/usr/bin/perl

use strict;
use warnings;
use File::Find;

my $dbname = shift @ARGV;
my $dbuser = shift @ARGV;
my $dbpass = shift @ARGV;
my $threads = shift @ARGV;
my $startdir = shift @ARGV;

die "Bad dir: $startdir" if !-d $startdir;

my @queue = getSqlDirs($startdir);

my $running = 0;

while (@queue > 0) {
    # launch max number of readers
    while ($running < $threads && @queue > 0) {
	my $dir = shift @queue;
	processDir($dir);
	$running++;
    }
    # and wait for someone to die
    $running-- if wait() != -1;
}

# wait for the rest of the children to finish
while (wait() != -1) { };

exit(0);


sub getSqlDirs {
    my $dir = shift @_;

    opendir(DIR, $dir) || die "opendir: $!";
    my @files = readdir(DIR);
    closedir(DIR);

    @files = grep { $_ !~ m/^\./ } @files;
    @files = map { $dir.'/'.$_ } @files;
    @files = grep { -d $_ } @files;
    return @files;
}

sub processDir {
    my $dir = shift @_;

    my $pid = fork();
    return if $pid != 0;

    open(MYSQL, "| mysql -u $dbuser -p$dbpass $dbname");

    find({
	wanted => sub {
	    return if ! -f $File::Find::name;
	    my $lastTable = '';
	    my $statement = undef;
	    open(INPUT, $File::Find::name) || die "open($File::Find::name): $!";
	    while (<INPUT>) {
		next if !m/^(?:INSERT|REPLACE)/;
		if (m/^(?:INSERT|REPLACE) INTO (\w+) (.*?) VALUES \((.*)\);/) {
		    if ($1 ne $lastTable || length($statement) > 2*1024*1024) {
			print MYSQL $statement, ";\n" if defined $statement;
			$statement = undef;
			$lastTable = $1;
		    }
		    if (!defined $statement) {
			$statement = "INSERT INTO $1 VALUES ($3)";
		    } else {
			$statement .= ",($3)";
		    }
		}
	    }
	    print MYSQL $statement, ";\n" if defined $statement;
	    close(INPUT);
	}}, $dir);
    print MYSQL "\nquit\n";
    close(MYSQL);
    exit(0);
}


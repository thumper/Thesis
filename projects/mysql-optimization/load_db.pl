#!/usr/bin/perl

use strict;
use warnings;
use File::Find;

my $threads = shift @ARGV;
my $startdir = shift @ARGV;

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

    close(STDOUT);
    open(STDOUT, "| mysql -u debian-sys-maint -pOSNZHR9DOKOf5lfT ptwikidb");

    find({
	wanted => sub {
	    return if ! -f $File::Find::name;
	    open(INPUT, $File::Find::name) || die "open($File::Find::name): $!";
	    while (<INPUT>) {
		print;
	    }
	    close(INPUT);
	}}, $dir);
    print "\nquit\n";
    close(STDOUT);
    exit(0);
}


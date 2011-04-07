#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;
use Data::Dumper;
use File::Find;

my ($revids, $dumpFileOrDir) = @ARGV;

my $revs = {};

readCSV($revids, [0, 1], sub {
    my ($revid, $class) = @_;
    $revs->{$revid} = { class => $class };
});

searchFiles($dumpFileOrDir);

exit(0);

sub processFile {
    return if -d $_;

    my $file = $_;
    if (m/\.gz$/) {
	open(INPUT, "gunzip -c $file |") die "gunzip($file): $!";
    } else {
	open(INPUT, "7za e -so $file |") die "7za($file): $!";
    }
    # what do we care about in a file?  The header, in case
    # create a new dump, the start of a page, and the
    # relevant revs in the page.
    my @important;
    my $keeppage = 0;
    my $linepos = 0;
    my ($header, $page, $rev);
    while (<INPUT>) {
	if (m/^<mediawiki\b/) {
	    $header = [$linepos, -1];
	}
	if (m/^\s+<page>/) {
	    $keeppage = 0;
	    $header->[1] = $linepos - 1 if $header->[1] == -1;
	    $page = [$linepos, -1];
	}
	if (m/^\s+<\/page>/) {
	    $page = undef if !$keeppage;
	}
	if (m/^\s+<revision>/) {
	    $keeprev = 0;
	    $important[-1]->[1] = $linepos - 1 if $important[-1]->[1] == -1;
	    push @important, [$linepos, -1];
	}
    }
    close(INPUT);
}


sub searchFiles {
    my ($fileOrDir) = @_;

    if (-d $fileOrDir) {
	find({ wanted => \&processFile, no_chdir => 1 },
		$fileOrDir);
    } else {
	local $_ = $fileOrDir;
	processFile($fileOrDir);
    }
}

sub readCSV {
    my $file = shift @_;
    my $fields = shift @_;
    my $func = shift @_;
    my $csv = Text::CSV->new({'binary' => 1});
    open(INPUT, "<".$file) || die "open($file): $!";
    while (<INPUT>) {
	chomp;
	$csv->parse($_) || die "csv parsing error on: " . $csv->error_input
		."\n" . $csv->error_diag();
	my @cols = $csv->fields();
	$func->(map { $cols[$_] } @$fields);
    }
    close(INPUT);
}


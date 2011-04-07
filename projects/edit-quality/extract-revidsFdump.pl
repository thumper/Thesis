#!/usr/bin/perl

use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Queue;
use Text::CSV;
use Data::Dumper;
use File::Find;
use List::Util qw(max);

my ($revids, $dumpFileOrDir) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 1], sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
});

my $q = Thread::Queue->new();
my $output = threads->create(\&getOutput, $q);

searchFiles($dumpFileOrDir);

my $done :shared = { finished => 1 };
$q->enqueue($done);

$output->join();

exit(0);

sub getOutput {
    my $q = shift @_;
    while (my $pages = $q->dequeue()) {
	last if exists $item->{finished};
	next if @$pages == 0;
	my $file = $pages->[0]->{file};
	if ($file =~ m/\.gz$/) {
	    open(INPUT, "gunzip -c $file |") die "gunzip($file): $!";
	} else {
	    open(INPUT, "7za e -so $file |") die "7za($file): $!";
	}
	foreach my $page (@$pages) {
	    sysseek(INPUT, $page->{start}, 0);
	    my $pagehdr = '';
	    sysread(INPUT, $pagehdr, $page->{end} - $page->{start});
	    print $pagehdr;
	    foreach my $rev (@{ $page->{revs} }) {
		sysseek(INPUT, $rev->{start}, 0);
		my $revdata = '';
		sysread(INPUT, $revdata, $rev->{end} - $rev->{start});
		print $revdata;
	    }
	    print "  </page>\n";
	}
	close(<INPUT>);
    }
}

sub keepUsefulPages {
    my $pages = shift @_;
    my $i = 0;
    while ($i < @$pages) {
	my $revs = $pages->[$i]->{revs};
	my @newrevs;		# our new final list of revs
	my %seen;		# what we've already put on new list
        for (my $j = 0; $j < @$revs; $j++) {
	    next if !exists $panrevs->{ $revs->[$currev]->{revid} };
	    # found one, so add the previous rev, and the 20 following
	    for (my $k = max(0, $j-1); $k < min(@$revs, $j+20); $k++) {
		my $revid = $revs->[$k];
		next if $seen{$revid}++;
		push @newrevs, $revid;
	    }
	}
	$pages->[$i]->{revs} = \@newrevs;
    }
}

sub processFile {
    return if -d $_;

    my $file = $_;
    if (m/\.gz$/) {
	open(INPUT, "gunzip -c $file |") die "gunzip($file): $!";
    } else {
	open(INPUT, "7za e -so $file |") die "7za($file): $!";
    }
    # what do we care about in a file?
    # the start of a page, and the location of revs
    my $linepos = 0;
    my $inrev = 0;
    my $linepos = 0;
    my (@page);
    while (<INPUT>) {
	if (m/^\s+<page>/) {
	    push @page, {
		file => $file,
		start => $linepos,
		end => undef,
		revs => []
	    };
	}
	if (m/^\s+<revision>/) {
	    $inrev = 1;
	    $page[-1]->{end} = $linepos if !defined $page[-1]->{end};
	    push @{ $page[-1]->{revs} }, {
		start => $linepos,
		end => undef,
		revid => undef,
	    };
	}
	if (m/^\s+<id>(\d+)<\/id>/) {
	    # Are we in a page, or a revision?
	    # both use the same tag.  :(
	    $page[-1]->{revs}->[-1]->{revid} = $1 if $inrev;
	}
	$linepos = tell INPUT;
	if (m/^\s+<\/revision>/) {
	    # This goes after update to linepos, because we want
	    # to include this last line
	    $page[-1]->{revs}->[-1]->{end} = $linepos;
	    $inrev = 0;
	}
    }
    close(INPUT);
    keepUsefulPages(\@page);
    $q->enqueue(\@page);
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


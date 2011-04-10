#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;
use Data::Dumper;
use File::Find;
use List::Util qw(max min);

my ($revids, $dumpFileOrDir) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 1], sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
});

initOutput();
searchFiles($dumpFileOrDir);
finalOutput();

exit(0);

sub doOutput {
    my $pages = shift @_;
    return if @$pages == 0;
    my $page = $pages->[0];
    last if exists $page->{finished};
    my $file = $page->{file};
    if ($file =~ m/\.gz$/) {
	open(INPUT, "gunzip -c $file |") || die "gunzip($file): $!";
    } elsif ($file =~ m/\.7z$/) {
	open(INPUT, "7za e -so $file |") || die "7za($file): $!";
    } else {
	open(INPUT, "<$file") || die "open($file): $!";
    }
warn "file: $file\n";
    foreach my $page (@$pages) {
	next if @{ $page->{revs} } == 0;
warn "page: ".$page->{start}. " to ". $page->{end}."\n";
	my $diff = $page->{start} - tell(INPUT);
	my $junk = '';
	while ($diff > 0) {
	    $diff = 1 * 1024 * 1024 if $diff > 1024 * 1024;
	    read(INPUT, $junk, $diff);
	    $diff = $page->{start} - tell(INPUT);
	}
	my $pagehdr = '';
	read(INPUT, $pagehdr, $page->{end} - $page->{start});
	print $pagehdr;
	foreach my $rev (@{ $page->{revs} }) {
if (!defined $rev->{end} || !defined $rev->{start}) {
    die "bad rev: ".Dumper($rev);
}
warn "rev: ".$rev->{start}. " to ". $rev->{end}."\n";
	    my $diff = $rev->{start} - tell(INPUT);
	    my $junk = '';
	    while ($diff > 0) {
		$diff = 1 * 1024 * 1024 if $diff > 1024 * 1024;
		read(INPUT, $junk, $diff);
		$diff = $rev->{start} - tell(INPUT);
	    }
	    my $revdata = '';
	    read(INPUT, $revdata, $rev->{end} - $rev->{start});
	    print $revdata;
	}
	print "  </page>\n";
    }
    close(INPUT);
}

sub keepUsefulPages {
    my $pages = shift @_;
    my $i = 0;
    while ($i < @$pages) {
	my $revs = $pages->[$i]->{revs};
warn "found ".scalar(@$revs)." revs\n";
	my @newrevs;		# our new final list of revs
	my %seen;		# what we've already put on new list
        for (my $j = 0; $j < @$revs; $j++) {
	    next if !exists $panrevs->{ $revs->[$j]->{revid} };
	    # found one, so add the previous rev, and the 20 following
	    for (my $k = max(0, $j-1); $k < min(scalar(@$revs), $j+20); $k++) {
		my $revid = $revs->[$k];
		next if $seen{$revid}++;
		push @newrevs, $revid;
	    }
	}
warn "\tkeeping ".scalar(@newrevs)." revs\n";
	$pages->[$i]->{revs} = \@newrevs;
	$i++;
    }
}

sub processFile {
    return if -d $_;

    my $file = $_;
    if (m/\.gz$/) {
	open(INPUT, "gunzip -c $file |") || die "gunzip($file): $!";
    } elsif (m/\.7z$/) {
	open(INPUT, "7za e -so $file |") || die "7za($file): $!";
    } else {
	open(INPUT, "<$file") || die "open($file): $!";
    }
    # what do we care about in a file?
    # the start of a page, and the location of revs
    my $linepos = 0;
    my $inrev = 0;
    my (@page);
    while (<INPUT>) {
	if (m/^\s*<page>/) {
	    push @page, {
		file => $file,
		start => $linepos,
		end => undef,
		revs => []
	    };
	}
	if (m/<revision>/) {
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
	    $page[-1]->{revs}->[-1]->{revid} = $1
		if $inrev && !defined $page[-1]->{revs}->[-1]->{revid};
	}
	$linepos = tell INPUT;
	if (m/^\s*<\/revision>/) {
	    # This goes after update to linepos, because we want
	    # to include this last line
	    $page[-1]->{revs}->[-1]->{end} = $linepos;
	    $inrev = 0;
	}
    }
    close(INPUT);
    keepUsefulPages(\@page);
    doOutput(\@page);
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

sub initOutput {
    print <<_EOT_;
<mediawiki xmlns="http://www.mediawiki.org/xml/export-0.4/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.mediawiki.org/xml/export-0.4/ http://www.mediawiki.org/xml/export-0.4.xsd" version="0.4" xml:lang="en">
  <siteinfo>
    <sitename>Wikipedia</sitename>
    <base>http://en.wikipedia.org/wiki/Main_Page</base>
    <generator>MediaWiki 1.16alpha-wmf</generator>
    <case>first-letter</case>
    <namespaces>
      <namespace key="-2">Media</namespace>
      <namespace key="-1">Special</namespace>
      <namespace key="0" />
      <namespace key="1">Talk</namespace>
      <namespace key="2">User</namespace>
      <namespace key="3">User talk</namespace>
      <namespace key="4">Wikipedia</namespace>
      <namespace key="5">Wikipedia talk</namespace>
      <namespace key="6">File</namespace>
      <namespace key="7">File talk</namespace>
      <namespace key="8">MediaWiki</namespace>
      <namespace key="9">MediaWiki talk</namespace>
      <namespace key="10">Template</namespace>
      <namespace key="11">Template talk</namespace>
      <namespace key="12">Help</namespace>
      <namespace key="13">Help talk</namespace>
      <namespace key="14">Category</namespace>
      <namespace key="15">Category talk</namespace>
      <namespace key="100">Portal</namespace>
      <namespace key="101">Portal talk</namespace>
      <namespace key="108">Book</namespace>
      <namespace key="109">Book talk</namespace>
    </namespaces>
  </siteinfo>
_EOT_
}

sub finalOutput {
    print "</mediawiki>\n";
}


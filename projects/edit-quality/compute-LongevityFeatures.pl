#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use List::Util qw( sum min );
use Switch;
use Time::HiRes qw( gettimeofday tv_interval );
use lib 'lib';
use PAN;
use MediawikiDump;
use lib '../diff/WikiTrust-Text/lib';
use WikiTrust::FasterTextTracking;
use WikiTrust::FasterDiff;
use constant KEEP_POINTS => 10;

my ($dumpFileOrDir) = @ARGV;

my $pageData = cleanPage();
my $dump = MediawikiDump->new(\&page_start, \&page_end, \&rev_handler);
$dump->process($dumpFileOrDir);
exit(0);

sub cleanPage {
    return {
	filteringQ => [],
	filteredQ => [],
	revtime => 0,
    };
}

sub getAuthorFRev {
    my $rev = shift @_;
    my $author = $rev->{contributor}->[0]->{username}->[0];
    $author = $rev->{contributor}->[0]->{ip}->[0] if !defined $author;
    return $author;
}

sub getRevidFRev {
    my $rev = shift @_;
    my $revid = $rev->{id}->[0];
    die "Bad revid" if !defined $revid;
    return $revid;
}

sub getSurvivalFWords {
    my $words = shift @_;
    my %byauthor;
    foreach my $w (@$words) {
	$byauthor{$w->[1]}++;
    }
    return \%byauthor;
}


sub checkForWork {
    my $filterq = $pageData->{filteringQ};
    return if @$filterq < 2;
    my $author0 = getAuthorFRev($filterq->[0]);
    my $author1 = getAuthorFRev($filterq->[1]);
    my $rev = shift @$filterq;
    return if $author0 eq $author1;	# filter out this rev
    
    # Otherwise, it's good.  First let's do some calculations.
    # We'll use the current work queue as the list of previous revisions.
    my $workq = $pageData->{filteredQ};

    my $revid = getRevidFRev($rev);
    my $text = $rev->{text}->[0]->{content} || '';
    $rev->{revid} = $revid;
    $rev->{author} = $author0;
    $pageData->{revtime} = [ gettimeofday ];
warn "processing revid $revid\n";

    my $tt = WikiTrust::FasterTextTracking->new();
    my $words = $tt->target($text, $revid);
    my @prevrevs = map { $_->{words} } @$workq;
    $words = $tt->track_text(\@prevrevs);
my $now = [ gettimeofday ];
warn "\ttext tracking = ". tv_interval($pageData->{revtime}, $now)."\n";
$pageData->{revtime} = $now;
    $rev->{survival} = getSurvivalFWords($words);
    $rev->{words} = $words;		# store for next iteration
    $rev->{editlong} = 0.0;
    $rev->{editdist} = 0.0;

    # And finally put it on the work queue
    push @$workq, $rev;

    # What do we need to be able to compute longevity?
    # a) text longevity needs rev, plus 10 filtered revs after == 11 revs
    # b) edit longevity needs rev, plus rev before,
    #    plus 10 filtered revs after == 12 revs
    return if @$workq < 12;

    # get the oldest rev, and do whatever calculations we need to.
    # We pull it off the queue because we'll discard it once the
    # calculations are done.
    my $oldrev = shift @$workq;

    my $textlongevity = computeTextLongevity($oldrev, $workq);
$now = [ gettimeofday ];
warn "\ttext longevity = ". tv_interval($pageData->{revtime}, $now)."\n";
$pageData->{revtime} = $now;
    my $editlongevity = computeEditLongevity($oldrev, @$workq);
$now = [ gettimeofday ];
warn "\tedit longevity = ". tv_interval($pageData->{revtime}, $now)."\n";
$pageData->{revtime} = $now;
    $workq->[0]->{editlong} = $editlongevity;
    my $editdist = editdist($oldrev, $workq->[0]);
    $workq->[0]->{editdist} = $editdist;
    printf "%d,%f,%f,%f\n", $oldrev->{revid}, $textlongevity,
	$oldrev->{editlong},$oldrev->{editdist};
}

sub computeEditLongevity {
    my ($past, $current, @future) = @_;
    my $revid = $current->{revid};
    my $author = $current->{author};
    # we only care about the ten following revs
    while (@future > KEEP_POINTS) { pop @future; }
    # filter out evaluations by the original author
    @future = grep { $_->{author} ne $author } @future;
    die "No future revisions for revid $revid" if @future == 0;
warn "EL revid $revid has only ".scalar(@future)." judges\n" if @future < 6;
    my @longs = map { computeEditQuality($past, $current, $_) } @future;
    return sum(@longs) / scalar(@longs);
}

sub computeEditQuality {
    my ($past, $present, $future) = @_;

    return (editdist($past, $future) - editdist($present, $future))
	/ editdist($past, $present);
}

sub editdist {
    my ($source, $target) = @_;

    my $revid = $target->{revid};
    if (exists $source->{editdist}) {
	return $source->{editdist}->{$revid}
		if exists $source->{editdist}->{$revid};
    } else {
	$source->{editdist} = {};
    }

    my $s_text = $source->{text}->[0]->{content} || '';
    my $t_text = $target->{text}->[0]->{content} || '';

    my $diff = WikiTrust::FasterDiff->new();
    my $words = $diff->target($t_text);
    my $editScript = $diff->edit_diff($s_text);

    my $i_tot = 0;
    my $d_tot = 0;
    foreach my $m (@$editScript) {
	switch ($m->[0]) {
	    case "Ins" { $i_tot += $m->[2]; }
	    case "Del" { $d_tot += $m->[2]; }
	    case "Mov" { ; }
	    else { die "Bad script: ".$m->[0]; }
	};
    }
    my $dist = $i_tot + $d_tot - min($i_tot, $d_tot) / 2.0;
    $source->{editdist}->{$revid} = $dist;
    return $dist;
}

sub computeTextLongevity {
    my ($rev, $laterrevs) = @_;
    my $revid = $rev->{revid};
    my $author = $rev->{author};

    my @revlist = @$laterrevs;		# make copy of revs
    # we only care about the ten following revs
    while (@revlist > KEEP_POINTS) { pop @revlist; }
    # and none can be the same author
    @revlist = grep { $_->{author} ne $author } @revlist;
warn "TL revid $revid has only ".scalar(@revlist)." judges\n" if @revlist < 6;

    # but then we need the original rev on our list for the rest
    unshift @revlist, $rev;
    my @history = map { $_->{survival}->{$revid} || 0 } @revlist;
warn "\ttext survival: ".join(", ", @history)."\n";

    # and then we need to use Newton's method for solving
    # the exponential equation
    my $sum = sum @history;
    my $first = $history[0];

    my $func = sub {
	my $alpha = shift @_;
	return (1-$alpha) * $sum - $first * (1 - ($alpha**(KEEP_POINTS+1)));
    };
    my $funcPrime = sub {
	my $alpha = shift @_;
	return -$sum + $first * (KEEP_POINTS+1) * ($alpha ** KEEP_POINTS);
    };
    my $alpha = 0.0;
    my $last = 1.0;
    my $count = 0;
    while ($last - $alpha > 0.0001) {
	$count++;
	die "Bad count $count @ revid $revid" if $count > 50;
	$last = $alpha;
	$alpha = $alpha - ($func->($alpha) / $funcPrime->($alpha));
    }
    return $alpha;
}

sub page_start {
    my $data = shift @_;
    #my $xs = XML::Simple->new(ForceArray => 1);
    #my $p = $xs->XMLin(join('', @{ $data->{lines} }));
    $pageData = cleanPage();
}
sub page_end {
}
sub rev_handler {
    my $data = shift @_;
    my $xs = XML::Simple->new(ForceArray => 1);
    my $p = $xs->XMLin(join('', @{ $data->{lines} }));
    push @{ $pageData->{filteringQ} }, $p;
    checkForWork();
    return 0;
}


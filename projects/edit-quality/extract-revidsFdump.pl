#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use Carp;
use lib 'lib';
use PAN;
use MediawikiDump;

my ($revids, $dumpFileOrDir) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 1], sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
});

my $pageData = freshPage();
my $dump = MediawikiDump->new(sub {
	$pageData->{header} = shift @_;
	# We don't want the "</page>" part...
	pop @{ $pageData->{header}->{lines}};
    }, sub {
	print join('', @{ $pagedata->{lastrev}->{lines} })
	    if $pagedata->{printrevs} > 0;
	print "  </page>\n" if $pageData->{printpage};
	$pageData = freshPage();
    }, sub {
	rev_handler($panrevs, $pageData, @_);
    });
initOutput();
$dump->process($dumpFileOrDir);
finalOutput();
exit(0);

sub freshPage {
    return {
	header => undef,
	printrevs => 0,
	lastrev => undef,
	printpage => 0,
    };
}

sub rev_handler {
    my ($panrevs, $pagedata, $revdata) = @_;
if (0) {
    my $xs = XML::Simple->new(ForceArray => 1);
    my $p = $xs->XMLin(join('', @{ $revdata->{lines} }));
    my $revid = $p->{id}->[0];
}
    my $revid = undef;
    my $user = undef;
    foreach ( @{ $revdata->{lines} } ) {
	if (m/^\s*<id>(\d+)<\/id>/) {
	    $revid = $1;
	}
	if (m/^\s*<username>([^<]+)<\/username>/) {
	    $user = $1;
	}
	if (m/^\s*<ip>([^<]+)<\/ip>/) {
	    $user = $1;
	}
	last if defined $revid && defined $user;
    }
    die "Revision has no id?" if !defined $revid;
    die "Revision has no user?" if !defined $user;
    $revdata->{revid} = $revid;
    $revdata->{user} = $user;
    my $panrev = exists $panrevs->{$revid};
    if ($panrev) {
	# print out <page> tag if this is first time
	print join('', @{ $pagedata->{header}->{lines} })
	    if $pagedata->{printpage} == 0;
	$pagedata->{printpage} = 1;
	# And print out the lastrev and current rev.
	# We don't care if they have the same author,
	# because PAN is asking about this specific rev.
	print join('', @{ $pagedata->{lastrev}->{lines} })
	    if defined $pagedata->{lastrev};
	print join('', @{ $revdata->{lines} });
	$pagedata->{lastrev} = undef;
	# print out the pan rev and the 10 following filtered revs
	$pagedata->{printrevs} = 10;
	return;
    }
    if (!defined $pagedata->{lastrev}) {
	$pagedata->{lastrev} = $revdata;
	return;
    }
    # filter out revisions if user is the same
    if ($pagedata->{lastrev}->{user} eq $revdata->{user}) {
	$pagedata->{lastrev} = $revdata;
	return;
    }
    # print out lastrev if we're wanting that
    if ($pagedata->{printrevs} > 0) {
	print join('', @{ $pagedata->{lastrev}->{lines} });
	$pagedata->{printrevs}--;
    }
    # and shift current one into lastrev
    $pagedata->{lastrev} = $revdata;
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


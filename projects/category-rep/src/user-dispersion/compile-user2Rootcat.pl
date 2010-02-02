#!/usr/bin/perl -w
# NOTE: This program reads a new-format file to calculate
# which categories editors participate in, and how much.

use strict;
use Getopt::Long;

my %optctl = (
    mode => 'text',
);

GetOptions(\%optctl, "mode=s");

my (%pages);
&readData();

my %pageCount;
my %revs;
my @buffer;
my $eof = 0;

my %userContribs;

while (my $fields = getline()) {
    my $pageId = $fields->[3];
    my $userId = $fields->[7];
    my $contrib = 0;
    $contrib = $fields->[17] if $optctl{mode} eq 'text';
    $contrib = $fields->[27] if $optctl{mode} eq 'edit';
    $contrib = 1 if $optctl{mode} eq 'cats';

    # we don't want to count *every* TextInc,
    # only ones that are one apart -- so we count
    # each contribution only once.
    my $judgedRev = $fields->[5];
    my $judgeRev = $fields->[11];
    next if getRevNum($pageId, $judgeRev) - getRevNum($pageId, $judgedRev) != 1;

    $userContribs{$userId} = {} if !exists $userContribs{$userId};
    my $cats = $pages{$pageId} || [];
    foreach my $catId (@$cats) {
        $userContribs{$userId}->{$catId} += $contrib;
    }
}

while (my ($userId, $ref) = each %userContribs) {
    my $totalCats = scalar(keys %$ref);
    print "User $userId TotalCats $totalCats";
    my @cats = sort { $ref->{$b} <=> $ref->{$a} } keys %$ref;
    my $totalContribs = 0;
    foreach my $c (@cats) {
        $totalContribs += $ref->{$c};
    }
    if (@cats > 0 && $totalContribs == 0.0) {
	warn "A user with no contributions? Uid $userId\n";
	foreach my $c (@cats) {
	    warn "\tcategory $c ==> ".$ref->{$c}."\n";
	}
	print "\n";
	next;
    }

    # normalize contributions into percentages
    foreach my $c (@cats) {
        $ref->{$c} /= $totalContribs;
    }

    # and find out how many cats responsible for 25% of contributions, etc.
    my $participation = 0.0;
    my @track = (25, 33, 50, 66, 75, 90);
    my $found = 0;
    my $numcats = 0;
    foreach my $c (@cats) {
    	$participation += $ref->{$c};
	$numcats++;
	while ($found < @track && $participation >= ($track[$found]/100.0)) {
	    print " Part$track[$found] $numcats";
	    $found++;
	}
    	last if $found >= @track;
    }
    print " Cats";
    foreach my $c (@cats) {
	print " ", $c;
    }
    print "\n";
}

exit(0);

sub getRevNum {
    my ($pageId, $revId) = @_;
    return $revs{$revId} if exists $revs{$revId};
    $revs{$revId} = ++$pageCount{$pageId};
    return $revs{$revId};
}

sub getline {
    if ((@buffer < 2) && !$eof) {
	%pageCount = ();
	%revs = ();
	# need to refill the buffer
	$eof = 1;
	while (defined ($_ = <>)) {
	    next if !m/^TextInc/;
	    chomp;
	    my @fields = split(' ');
	    push @buffer, \@fields;
	    if ((@buffer >= 2) && ($buffer[-1]->[1] != $buffer[-2]->[1])) {
		$eof = 0;
		last;
	    }
	}
	# figure out what revisions are mentioned,
	# but don't look at the last line read in,
	# which is for the next timestamp!
	my @revs;
	for (my $r = 0; $r < @buffer - 1; $r++) {
	    my $rec = $buffer[$r];
	    if ($rec->[0] eq 'TextLife') {
		push @revs, [$rec->[3], $rec->[5]];
	    } elsif ($rec->[0] eq 'TextInc') {
		push @revs, [$rec->[3], $rec->[5]];
		push @revs, [$rec->[3], $rec->[11]];
	    } elsif ($rec->[0] eq 'EditLife') {
		push @revs, [$rec->[3], $rec->[5]];
	    } elsif ($rec->[0] eq 'EditInc') {
		push @revs, [$rec->[3], $rec->[5]];
		push @revs, [$rec->[3], $rec->[11]];
	    }
	}
	@revs = sort { $a->[1] <=> $b->[1] } @revs;
	foreach my $r (@revs) {
	    getRevNum(@$r);
	}
    }
    return shift @buffer;
}

sub readData {
    open(my $rootcatfh, "<:encoding(iso-8859-1)", "page2rootcat.txt") || die "open: $!";
    while (<$rootcatfh>) {
	my @cats = split(' ');
	my $pageId = shift @cats;
	shift @cats;
	$pages{$pageId} = \@cats;
    }
    close($rootcatfh);
}


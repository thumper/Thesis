#!/usr/bin/perl -w

# load up the contributions
# and figure out the rankings for each user.
# Compare the rankings, to find out who has
# changed position the most.

use strict;
use Getopt::Long;

my %optctl = (
    'percentiles' => 0,
    );
GetOptions(\%optctl, "percentiles");

my %rankings;

# load the contributions
my ($header, $contribs) = readContribs();
for (my $i = 1; $i < @$header; $i++) {
    my $users = convert2Ranking($contribs, $i-1);
    while (my ($uid, $rank) = each %$users) {
	$rankings{$uid} = [] if !exists $rankings{$uid};
	push @{ $rankings{$uid} }, $rank;
    }
}

my $numusers = scalar(keys %rankings);

print join("\t", @$header), "\n";
while (my ($key, $val) = each %rankings) {
    if ($optctl{percentiles}) {
	foreach (@$val) {
	    $_ = 100.0 * $_ / $numusers;
	    # round to 1/10th percent
	    $_ = int($_ * 10.0 + 0.5) / 10.0;
	}
    }
    print join("\t", $key, @$val), "\n";
}
exit(0);

sub readContribs {

    my $line = <>;
    chomp($line);
    my @header = split(' ', $line);
    my %users;
    while (<>) {
        chomp;
	my @fields = split(' ');
	my $uid = shift @fields;
	$users{$uid} = \@fields;
    }
    return (\@header, \%users);
}

sub convert2Ranking {
    my ($contribs, $pos) = @_;

    my %users = map { $_ => $contribs->{$_}->[$pos] } keys %$contribs;

    my @rankings = sort { $users{$a} <=> $users{$b} } keys %users;
    # now assign actual rank.
    for (my $i = 0; $i < @rankings;) {
	my $currentScore = $users{$rankings[$i]};
	my $j = $i+1;
	while ($j < @rankings && $users{$rankings[$j]} == $currentScore) {
	    $j++;
	}
	# now the range [$i,$j) are all tied.
	# To minimize variation in ranks when there are ties, we use the mean rank.
	### old code: my $rank = ($i + $j - 1) / 2.0;
	my $rank = $j - 1;
	while ($i < $j) {
	    $users{$rankings[$i]} = $rank;
	    $i++;
	}
    }

    return \%users;
}



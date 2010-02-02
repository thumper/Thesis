#!/usr/bin/perl -w

# load up the contributions from each contrib file,
# and figure out the rankings for each user.
# Compare the rankings, to find out who has
# changed position the most.

use strict;


my %rankings;
# load the rankings from each file
foreach my $file (@ARGV) {
    my $users = readFile($file);
    while (my ($key, $val) = each %$users) {
	$rankings{$key} = [] if !exists $rankings{$key};
	push @{ $rankings{$key} }, $val;
    }
}

# cleanup filenames to be column headers
foreach (@ARGV) {
    s/\.txt//;
    s/^.*\-//;
    s/^\d+//;
}

# remove users that don't have complete data
my $numusers;
while (my ($key, $val) = each %rankings) {
    if (@$val != @ARGV) { delete $rankings{$key}; }
    else { $numusers++; }
}

print join("\t", "uid", @ARGV), "\n";
while (my ($key, $val) = each %rankings) {
    foreach (@$val) {
	$_ = 100.0 * $_ / $numusers;
	# round to 1/10th percent
	$_ = int($_ * 10.0 + 0.5) / 10.0;
    }
    print join("\t", $key, @$val), "\n";
}
exit(0);

sub readFile {
    my $file = shift @_;

    my %users;

    open(my $input, "<", $file) || die "open($file): $!";
    while (<$input>) {
	if (m/\bUid (\d+)\b.*\bContribution ([0-9\.\-]+)\b/) {
	    $users{$1} = $2;
	}
    }
    close($input);

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
	my $rank = ($i + $j - 1) / 2.0;
	while ($i < $j) {
	    $users{$rankings[$i]} = $rank;
	    $i++;
	}
    }

    return \%users;
}



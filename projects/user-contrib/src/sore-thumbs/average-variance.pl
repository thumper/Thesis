#!/usr/bin/perl -w

# read in a file of compiled data

use strict;
use constant ALLOWED_VARIANCE => 4;
use constant ALLOWED_VAR_VARIANCE => 4;

die "wrong number of args" if @ARGV != 1;
my $file = shift @ARGV;

my %users;
my @diffs;

open(my $in, "<", $file) || die "open: $!";
my $header = <$in>;
chomp($header);
while (<$in>) {
    chomp;
    my ($uid, @fields) = split(' ');
    $users{$uid} = \@fields;

    my ($avg, $variance) = computeStats(@fields);
    push @diffs, $variance;

    # On an individual basis, are any of numbers far away?
    foreach my $contrib (@fields) {
	my $delta = $avg - $contrib;
	my $devsq = $delta * $delta;
	if ($devsq > ALLOWED_VARIANCE * $variance) {
	    print "Type 1 User $uid Avg $avg Variance $variance BadVal $contrib Contribs ", join(' ', @fields), "\n";
	    last;
	}
    }
}
close($in);
print "Data NumUsers ", scalar(keys %users), "\n";


# Now find the "average" variance over all
# the records, and double check each record
# to see if there is a match
my ($avgVar, $varVar) = computeStats(@diffs);
print "Data AvgVariance $avgVar\n";
print "Data VarVariance $varVar\n";

while (my ($uid, $val) = each %users) {
    my ($avg, $variance) = computeStats(@$val);
    foreach my $contrib (@$val) {
	my $delta = $avg - $contrib;
	my $devsq = $delta * $delta;
	if ($devsq > ALLOWED_VAR_VARIANCE * $avgVar) {
	    print "Type 2 User $uid Avg $avg BadVal $contrib Contribs ", join(' ', @$val), "\n";
	    last;
	}
    }
}
exit(0);


sub computeStats {
    my $sum = 0.0;
    map { $sum += $_ } @_;
    my $avg = $sum / scalar(@_);
    my $sum_devsq = 0.0;
    map { my $delta = $avg - $_; $sum_devsq += $delta*$delta; } @_;
    my $variance = ($sum_devsq/@_);
    return ($avg, $variance);
}


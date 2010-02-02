#!/usr/bin/perl -w

# read in a file of compiled data

use strict;
use Getopt::Long;

my %optctl = (
    'not' => 0,
);

GetOptions(\%optctl, "not");

die "wrong number of args" if @ARGV != 1;

my ($datafile) = @ARGV;

my %watch;

while (<STDIN>) {
    chomp;
    $watch{$_} = 1;
}

open(my $in, "<", $datafile) || die "open: $!";
while (my $line = <$in>) {
    if ($line =~ m/^(\d+)\b/) {
	my $uid = $1;
	print $line if !$optctl{not} && exists $watch{$uid};
	print $line if $optctl{not} && !exists $watch{$uid};
    } elsif ($line =~ m/^uid\b/) {
	# always print the header
	print $line;
    }
}
close($in);
exit(0);


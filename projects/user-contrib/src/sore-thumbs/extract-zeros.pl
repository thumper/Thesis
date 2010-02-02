#!/usr/bin/perl -w
use strict;

# Find the users who have 0 editlong2 contributions.
# Why do they have 0?

die "wrong number of args" if @ARGV != 2;
my ($colname, $file) = @ARGV;


open(my $in, "<", $file) || die "open($file): $!";
my $line = <$in>;
print $line;
my @headers = split(' ', $line);
my $col = getCol($colname);
while (<$in>) {
    chomp;
    my @fields = split(' ');
    next if $fields[$col] != 0.0;
    my $uid = shift @fields;
    print "$uid\n";
}
close($in);

exit(0);

sub getCol {
    for (my $i = 1; $i < @headers; $i++) {
	return $i if $headers[$i] eq $_[0];
    }
    return undef;
}

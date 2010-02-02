#!/usr/bin/perl -w
use strict;

# Find the users who have 0 editlong2 contributions.
# Why do they have 0?

die "wrong number of args" if @ARGV != 1;
my ($file) = @ARGV;

my $moreText = 0;
my $moreEdit = 0;
my $equal = 0;

open(my $in, "<", $file) || die "open($file): $!";
my $line = <$in>;
my @headers = split(' ', $line);
my $editCol = getCol('editonly');
my $textCol = getCol('textonly');
while (<$in>) {
    chomp;
    my @fields = split(' ');
    my $text = $fields[$textCol];
    my $edit = $fields[$editCol] - $text;
    if ($text > $edit) {
    	$moreText++;
    } elsif ($edit > $text) {
    	$moreEdit++;
    } else {
    	$equal++;
    }
}
close($in);

print "More text = $moreText\n";
print "More edit = $moreEdit\n";
print "equal     = $equal\n";

exit(0);

sub getCol {
    for (my $i = 1; $i < @headers; $i++) {
	return $i if $headers[$i] eq $_[0];
    }
    return undef;
}

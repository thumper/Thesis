#!/usr/bin/perl -w

use strict;
use constant ALLOWED_VARIANCE => 1.4;

my %users;

my $filenum = 1;

# Read in the data from all the files, into a single structure
for (my $fnum = 0; $fnum < @ARGV; $fnum++) {
    my $file = $ARGV[$fnum];
    foreach my $level (0..9) {
	my $repfile = "$file-level$level";
	unlink($repfile);
    }
    open(INPUT, "<", $file) || die "open($file): $!";
    $file =~ s#.*/##;
    while (<INPUT>) {
	if (m/\bReputation (\d+)\s+Contribution ([0-9\.\-]+)\b/) {
	    my $rep = $1;
	    my $contrib = $2;
	    open(my $out, ">>:utf8", "$file-level$rep") || die "open($file-level$rep): $!";
	    print $out "$contrib\n";
	    close($out);
	}
    }
    close(INPUT);
}

exit(0);

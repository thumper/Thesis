#!/usr/bin/perl -w
use strict;

foreach my $file (@ARGV) {
    process($file);
}
exit(0);

sub process {
    my $file = shift @_;
    warn "\tcleaning $file\n";
    my %seen;
    my $outfile = "$file.tmp";
    open(my $out, ">", $outfile) || die "open: $!";
    open(my $in, "<", $file) || die "open: $!";
    while (<$in>) {
	if (m/\bPls\s*$/) {
	    next if $seen{$_};
	    $seen{$_} = 1;
	}
	print $out $_;
    }
    close($in);
    close($out);
    rename($outfile, $file) || die "rename: $!";
}


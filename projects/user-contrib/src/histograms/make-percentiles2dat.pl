#!/usr/bin/perl -w
use strict;
use constant INCREMENT => 1;		# need to fix code, too
use Math::Round qw(nhimult);

die "wrong number of args" if @ARGV < 1;
my ($file, $outdir) = @ARGV;


open(my $in, "<", $file) || die "open($file): $!";
my $line = <$in>;
my @headers = split(' ', $line);
my %users;
while (<$in>) {
    chomp;
    my @fields = split(' ');
    my $uid = shift @fields;
    foreach (@fields) {
	$_ = $_ + 0;
    }
    $users{$uid} = \@fields;
}

close($in);
for (my $x = 1; $x < @headers; $x++) {
    for (my $y = $x+1; $y < @headers; $y++) {
    	my $out = "$outdir/hist-pctl-$headers[$x]-$headers[$y].dat";
        hist($out, $x, $y, $headers[$x], $headers[$y], 0);
    }
}
exit(0);

sub hist {
    my ($output, $col1, $col2) = @_;

    # swap cols to be alphabetical
    if ($headers[$col2] lt $headers[$col1]) {
	my $tmp = $col1;
	$col1 = $col2;
	$col2 = $tmp;
    }
    my $col1name = $headers[$col1--];
    my $col2name = $headers[$col2--];


    my %data;
    while (my ($uid, $vals) = each %users) {
	my $x = $vals->[$col1];
	my $y = $vals->[$col2];
	# Don't choose nearest... round up
	$x = nhimult(INCREMENT, $x);
	$y = nhimult(INCREMENT, $y);
	$data{$x}->{$y}++;
    }

    open(my $out, ">", $output) || die "open: $!";
    for (my $x = 0; $x <= 100; $x += INCREMENT) {
	for (my $y = 0; $y <= 100; $y += INCREMENT) {
	    print $out join("\t", $x, $y, ($data{$x}->{$y} || 0.0)), "\n";
	}
	print $out "\n";
    }
    close($out);
}


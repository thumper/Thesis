#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;
use Data::Dumper;

my ($editfile, $goldfile) = @ARGV;

my $edits = {};

readCSV($editfile, [0, 3], sub {
    my ($editid, $newrevid) = @_;
    $edits->{$editid} = { revid => $newrevid };
});

readCSV($goldfile, [0, 1], sub {
    my ($editid, $class) = @_;
    $edits->{$editid}->{class} = $class;
});


print Dumper($edits);
exit(0);

sub readCSV {
    my $file = shift @_;
    my $fields = shift @_;
    my $func = shift @_;
    my $csv = Text::CSV->new({'binary' => 1});
    open(INPUT, "<".$file) || die "open($file): $!";
    while (<INPUT>) {
	chomp;
	$csv->parse($_) || die "csv parsing error on: " . $csv->error_input
		."\n" . $csv->error_diag();
	my @cols = $csv->fields();
	$func->(map { $cols[$_] } @$fields);
    }
    close(INPUT);
}


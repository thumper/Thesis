#!/usr/bin/perl

use strict;
use warnings;
use Text::CSV;
use Data::Dumper;
use Date::Manip::Date;

my ($editfile, $goldfile) = @ARGV;

my $edits = {};

my $dateObj = Date::Manip::Date->new();

readCSV($editfile, [0, 3, 5], sub {
    my ($editid, $newrevid, $date) = @_;
    my $err = $dateObj->parse($date);
    die "date parse error: $err" if defined $err;
    my $secs = $date->secs_since_1970_GMT();
    $edits->{$editid} = { revid => $newrevid, 'time' => $secs };
});

readCSV($goldfile, [0, 1], sub {
    my ($editid, $class) = @_;
    $edits->{$editid}->{class} = $class;
});

print '"revid","time","class"'."\n";
foreach my $editid (keys %$edits) {
    print $edits->{$editid}->{revid}, ",",
	$edits->{$editid}->{'time'}, ",\"",
	$edits->{$editid}->{class}, "\"\n";
}

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


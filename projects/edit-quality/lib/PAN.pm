package PAN;
use strict;
use warnings;

use Carp;
use Text::CSV;
use Exporter 'import';
use vars qw( @EXPORT );
@EXPORT = qw( readCSV );

sub readCSV {
    my $file = shift @_;
    croak "No file specified" if !defined $file;
    my $fields = shift @_;
    my $func = shift @_;
    my $csv = Text::CSV->new({'binary' => 1});
    open(my $fh, "<".$file) || die "open($file): $!";
    $csv->column_names($csv->getline($fh));
    while (<$fh>) {
	chomp;
	$csv->parse($_) || die "csv parsing error on: " . $csv->error_input
		."\n" . $csv->error_diag();
	my @cols = $csv->fields();
	$func->(map { $cols[$_] } @$fields);
    }
    close($fh);
}

1;


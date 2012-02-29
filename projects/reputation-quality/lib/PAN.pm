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
    my $hdr_func = shift @_;
    my $func = shift @_;
    my $csv = Text::CSV->new({'binary' => 1, eol => $/, auto_diag => 2 });
    open(my $fh, "bunzip2 -c $file |") || die "open($file): $!";
    my $hdr = $csv->getline($fh);
    $hdr_func->($hdr);
    $csv->column_names($hdr);
    $fields = [0..scalar(@$hdr)-1] if !defined $fields;
    while (my $row = $csv->getline($fh)) {
	$func->(map { $row->[$_] } @$fields);
    }
    close($fh);
}

1;


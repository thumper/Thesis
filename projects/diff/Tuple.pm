package Tuple;
use strict;
use warnings;

use overload '<=>' => \&mycompare;

sub new {
    my $class = shift @_;
    my $values = [ @_ ];
    bless $values, $class;
}

sub mycompare {
    my ($a, $b, $order) = @_;
    my $i = 0;
    my $scale = 1;
    $scale = -1 if $order;
    while ($i < scalar(@$a)) {
	my $cmp = ($a->[$i] <=> $b->[$i]);
	return ($scale * $cmp) if $cmp != 0;
	$i++;
    }
    return 0;
}

1;

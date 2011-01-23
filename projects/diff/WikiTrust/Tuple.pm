package WikiTrust::Tuple;
use strict;
use warnings;

use Carp;

use overload '<=>' => \&mycompare;
use overload '>' => \&mybad;
use overload '<' => \&mybad;
use overload '==' => \&mybad;
use overload 'bool' => sub { return 1; };
use overload 'ne' => \&myne;

sub new {
    my $class = shift @_;
    my $values = [ @_ ];
    bless $values, $class;
}

sub mybad {
    confess "Illegal operator";
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

sub myne {
    my $cmp = mycompare(@_);
    return $cmp != 0;
}

1;

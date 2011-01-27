package WikiTrust::Tuple;
use strict;
use warnings;

use Carp;

use overload '<=>' => \&mycompare;
use overload '>' => \&mybad;
use overload '<' => \&mybad;
use overload '==' => \&mybad;
#use overload 'bool' => \&mybool;
use overload 'ne' => \&myne;
use overload 'eq' => \&myeq;
use overload '""' => \&mystring;

sub new {
    my $class = shift @_;
    my $values = [ @_ ];
    bless $values, $class;
}

sub mybad {
    confess "Illegal operator";
}

sub mybool {
    my ($a, $b, $order) = @_;
    return defined $a;
}

sub mycompare {
    my ($a, $b, $order) = @_;
    my $i = 0;
    my $scale = 1;
    $scale = -1 if $order;
    while ($i < scalar(@$a)) {
	my $cmp = 0;
	if ($a->[$i] =~ m/^\d+$/) {
	    $cmp = ($a->[$i] <=> $b->[$i]);
	} else {
	    $cmp = ($a->[$i] cmp $b->[$i]);
	}
	return ($scale * $cmp) if $cmp != 0;
	$i++;
    }
    return 0;
}

sub myne {
    my $cmp = mycompare(@_);
    return $cmp != 0;
}

sub myeq {
    my $cmp = mycompare(@_);
    return $cmp == 0;
}

sub mystring {
    my ($a, $b, $order) = @_;
    return "(". join(", ", @$a). ")";
}

1;

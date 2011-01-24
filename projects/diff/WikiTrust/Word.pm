package WikiTrust::Word;
use strict;
use warnings;

use Carp;

use overload '<=>' => \&mycompare;
use overload 'cmp' => \&mycompare;
use overload '>' => \&mybad;
use overload '<' => \&mybad;
use overload '==' => \&mybad;
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

sub mycompare {
    my ($a, $b, $order) = @_;
    my $i = 0;
    my $scale = 1;
    $scale = -1 if $order;
    my $cmp = $a->[0] cmp $b->[0];
    return ($scale * $cmp);
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
    return $a->[0];
}

1;

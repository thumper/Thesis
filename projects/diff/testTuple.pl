#!/usr/bin/perl

use strict;
use warnings;

use Tuple;

my $a = Tuple->new(5, 3, 2);
my $b = Tuple->new(5, 3, 1);

my $cmp = $b <=> $a;
print "Answer: $cmp\n";


#!/usr/bin/perl
use strict;
use warnings;
use lib '.';

use WikiTrustDiff;
use Data::Dumper;


sub runDiff {
    my @w1 = split(/\s+/, shift @_);
    my @w2 = split(/\s+/, shift @_);
    my $script = WikiTrustDiff::edit_diff(\@w1, \@w2);
    print Dumper($script);
}

my $w1 = "a b c d e o o o o o a b c d e";
my $w2 = "a b c d e q q a b c d e q q q q a b c d e";

runDiff($w1, $w2);


# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WikiTrust-Text.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 8;
BEGIN { use_ok('WikiTrust::BasicTextTracking') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

sub initVersion {
    my $revid = shift @_;
    my $str = shift @_;
    my $d = WikiTrust::BasicTextTracking->new();
    $d->set_minMatch(1);
    return $d->target($str, $revid);
}

sub runTracking {
    my $revid = shift @_;
    my $prevs = shift @_;
    my $dst = shift @_;
    my $d = WikiTrust::BasicTextTracking->new();
    $d->set_minMatch(1);
    $d->target($dst, $revid);
    my $words = $d->track_text($prevs);
    my %author;
    foreach my $w (@$words) {
	$author{$w->[1]}++;
    }
    return (\%author, $words);
}

my @prevrevs;
unshift @prevrevs,
    initVersion(123, "a b c d e o o o o o a b c d e");
my ($authors, $words) = runTracking(124, \@prevrevs,
    "a b c d e q q a b c d e q q q q a b c d e");
ok($authors->{124} == 6);
ok($authors->{123} == 15);
unshift @prevrevs, $words;
($authors, $words) = runTracking(125, \@prevrevs,
    "a b c d e o o o o o x y z a b c d e q q q q a b c d e");
ok($authors->{124} == 4);
ok($authors->{123} == 20);
ok($authors->{125} == 3);

my $w1 = "Today is the first day of the rest of your life";
my $w2 = "Today is the last day of your past";
@prevrevs = ();
unshift @prevrevs, initVersion(123, $w1);
($authors, $words) = runTracking(124, \@prevrevs, $w2);
ok($authors->{123} == 6);
ok($authors->{124} == 2);


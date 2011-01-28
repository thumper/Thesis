# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WikiTrust-Text.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 9;
BEGIN { use_ok('WikiTrust::Tuple') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $a = WikiTrust::Tuple->new(5, 6, 7);
my $b = WikiTrust::Tuple->new(5, 4, 3);
my $c = WikiTrust::Tuple->new(5, 5, 5);
my $d = WikiTrust::Tuple->new(5, 6, 7);
ok(($a <=> $b) == 1);
ok(($a <=> $c) == 1);
ok(($b <=> $c) == -1);
ok($a != $b);
ok($a != $c);
ok($b != $c);
ok($a == $d);
ok(($a <=> $d) == 0);


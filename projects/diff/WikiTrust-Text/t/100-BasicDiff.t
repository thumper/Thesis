# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WikiTrust-Text.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 30;
BEGIN { use_ok('WikiTrust::BasicDiff') };
BEGIN { use_ok('WikiTrust::FasterDiff') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#use Data::Dumper;


sub runDiff {
    my $diff = shift @_;
    my $d = "WikiTrust::$diff"->new();
    my $w1 = $d->parse(shift @_);
    $d->target(shift @_);
    my $script = $d->edit_diff($w1);
#    warn Dumper($script);
    return $script;
}

my $w1 = "a b c d e o o o o o a b c d e";
my $w2 = "a b c d e q q a b c d e q q q q a b c d e";
my $s = runDiff('BasicDiff', $w1, $w2);
ok(@$s == 4);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,0,5));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',10,16,5));
ok($s->[2] eq WikiTrust::Tuple->new('Del',5,5));
ok($s->[3] eq WikiTrust::Tuple->new('Ins',5,11));

$s = runDiff('FasterDiff', $w1, $w2);
ok(@$s == 4);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,0,5));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',10,16,5));
ok($s->[2] eq WikiTrust::Tuple->new('Del',5,5));
ok($s->[3] eq WikiTrust::Tuple->new('Ins',5,11));


$w1 = "Today is the first day of the rest of your life";
$w2 = "Today is the last day of your past";
$s = runDiff('BasicDiff', $w1, $w2);
ok(@$s == 8);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,0,3));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',8,5,2));
ok($s->[2] eq WikiTrust::Tuple->new('Mov',4,4,1));
ok($s->[3] eq WikiTrust::Tuple->new('Del',3,1));
ok($s->[4] eq WikiTrust::Tuple->new('Del',5,3));
ok($s->[5] eq WikiTrust::Tuple->new('Del',10,1));
ok($s->[6] eq WikiTrust::Tuple->new('Ins',3,1));
ok($s->[7] eq WikiTrust::Tuple->new('Ins',7,1));

$s = runDiff('FasterDiff', $w1, $w2);
ok(@$s == 8);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,0,3));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',8,5,2));
ok($s->[2] eq WikiTrust::Tuple->new('Mov',4,4,1));
ok($s->[3] eq WikiTrust::Tuple->new('Del',3,1));
ok($s->[4] eq WikiTrust::Tuple->new('Del',5,3));
ok($s->[5] eq WikiTrust::Tuple->new('Del',10,1));
ok($s->[6] eq WikiTrust::Tuple->new('Ins',3,1));
ok($s->[7] eq WikiTrust::Tuple->new('Ins',7,1));


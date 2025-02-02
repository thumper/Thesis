# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WikiTrust-Text.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 17;
BEGIN { use_ok('WikiTrust::ReplacementDiff') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

#use Data::Dumper;


sub runDiff {
    my $diff = shift @_;
    my $d = "WikiTrust::$diff"->new();
    $d->set_minMatch(1);
    my $w1 = shift @_;
    $d->target(shift @_);
    my $script = $d->edit_diff($w1);
#    warn Dumper($script);
    return $script;
}

my $w1 = "a b c d e o o o o o a b c d e";
my $w2 = "a b c d e q q a b c d e q q q q a b c d e";
my $s = runDiff('ReplacementDiff', $w1, $w2);
ok(@$s == 3);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,0,0,5));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',0,10,16,5));
ok($s->[2] eq WikiTrust::Tuple->new('Rep',0,5,5,5,11));

$w1 = "Today is the first day of the rest of your life";
$w2 = "Today is the last day of your past";
$s = runDiff('ReplacementDiff', $w1, $w2);
ok(@$s == 6);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,0,0,3));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',0,8,5,2));
ok($s->[2] eq WikiTrust::Tuple->new('Mov',0,4,4,1));
ok($s->[3] eq WikiTrust::Tuple->new('Rep',0,3,1,3,1));
ok($s->[4] eq WikiTrust::Tuple->new('Rep',0,10,1,7,1));
ok($s->[5] eq WikiTrust::Tuple->new('Del',5,3));

$w1 = "Four score and seven years ago";
$w2 = "Five score and seven days ago";
$s = runDiff('ReplacementDiff', $w1, $w2);
ok(@$s == 4);
ok($s->[0] eq WikiTrust::Tuple->new('Mov',0,1,1,3));
ok($s->[1] eq WikiTrust::Tuple->new('Mov',0,5,5,1));
ok($s->[2] eq WikiTrust::Tuple->new('Rep',0,0,1,0,1));
ok($s->[3] eq WikiTrust::Tuple->new('Rep',0,4,1,4,1));

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WikiTrust-Text.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
BEGIN { use_ok('WikiTrust::Tuple') };
BEGIN { use_ok('WikiTrust::BasicDiff') };
BEGIN { use_ok('WikiTrust::FasterDiff') };
BEGIN { use_ok('WikiTrust::BasicTextTracking') };
BEGIN { use_ok('WikiTrust::FasterTextTracking') };


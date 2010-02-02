#!/usr/bin/perl -w

# args are the contribution files in any order

use strict;
use Getopt::Long;

my %optctl = (
	normalize => 0,
	toprep => 0,
    );
GetOptions(\%optctl, "normalize");

warn "Not normalizing...\n" if !$optctl{normalize};

my %users;
my @maxVals;
my @minVals;

for (my $fnum = 0; $fnum < @ARGV; $fnum++) {
    $maxVals[$fnum] = undef;
    $minVals[$fnum] = undef;
    my $file = $ARGV[$fnum];
    open(INPUT, "<", $file) || die "open($file): $!";
    while (<INPUT>) {
	next if $optctl{toprep} && !m/\bReputation [789]\b/;
	if (m/\bUid (\d+)\b.*\bContribution ([0-9\.\-]+)\b/) {
	    $users{$1} = "" if !exists $users{$1};
	    $users{$1} .= $2.":";
	    my $c = $2 + 0;
	    $maxVals[$fnum] = $c if (!defined $maxVals[$fnum])
		|| $maxVals[$fnum] < $c;
	    $minVals[$fnum] = $c if (!defined $minVals[$fnum])
		|| $minVals[$fnum] > $c;
	}
    }
    close(INPUT);
}

while (my ($uid, $val) = each %users) {
    my @data = split(/:/, $val);
    delete $users{$uid} if @data != @ARGV;
}

warn "Data NumUsers ", scalar(keys %users), "\n";
for (my $fnum = 0; $fnum < @ARGV; $fnum++) {
    warn "file $ARGV[$fnum]\tMax $maxVals[$fnum]\tMin $minVals[$fnum]\n";
}
my $globalMax = foldl( \&max, @maxVals);
my $globalMin = foldl( \&min, @minVals);
warn "\tglobal maximum = $globalMax\n";
warn "\tglobal minimum = $globalMin\n";

if ($optctl{normalize}) {
    warn "Normalizing values...\n";
    while (my ($uid, $val) = each %users) {
	my @contribs = split(/:/, $val);
	my $max = exp(9);
	for (my $i = 1; $i < @contribs; $i++) {
	    # normalize to a range between 1 and 1000000.
#	    $contribs[$i] = log ( ($contribs[$i] - $minVals[$i])
#		    / ($maxVals[$i] - $minVals[$i]) * $max + 1);
	    $contribs[$i] = ( ($contribs[$i] - $globalMin) / ($globalMax - $globalMin) ) * $globalMax;
#            my $sign = ($contribs[$i] < 0)? -1 : 1;
#	    $contribs[$i] = $sign * log (1 + abs($contribs[$i]));
	}
	$users{$uid} = join(':', @contribs);
    }
};

# cleanup filenames to be column headers
foreach (@ARGV) {
    s/\.txt//;
    s/^.*\-//;
    s/^\d+//;
}
print join("\t", "uid", @ARGV), "\n";

while (my ($uid, $val) = each %users) {
    my @contribs = split(/:/, $val);
    print join("\t", $uid, @contribs),"\n";
}
exit(0);

sub cons { @_ }		# cons Atom List -> List
sub list { @_ }		# list Atoms -> List
sub car { $_[0] }	# car List -> Atom  -- the head of the list
sub cdr { shift; @_ }   # cdr List -> List -- the tail of the list
sub nullp { not @_ }
sub foldl {
    my ($kons, $knil, @list) = @_;
    (nullp @list) ? $knil : foldl($kons, &$kons((car @list),$knil), (cdr @list))
}

sub max { $_[0] < $_[1] ? $_[1] : $_[0]; }
sub min { $_[0] < $_[1] ? $_[0] : $_[1]; }


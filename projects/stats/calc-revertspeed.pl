#!/usr/bin/perl

# Go through article files and revisions by (timestamp, revid)

use strict;
use warnings;
use utf8;
use open IN => ":utf8", OUT => ":utf8";

use IO::Handle;
use File::Find;
use Encode;
use Error qw(:try);

use Carp;
use IO::Select;
use File::Path qw(mkpath);
use Storable qw(store_fd fd_retrieve);


my $indir = shift @ARGV;
my $outdir = shift @ARGV;

my (@subprocesses, %stats);
$stats{deltaT} = 0.0;
$stats{revs} = 0;
binmode STDOUT, ":utf8";
find({ wanted => \&wanted, no_chdir=>1 }, $indir);
while (@subprocesses > 0) { waitForChildren(); }
print "Total reverted revs = ".$stats{revs}."\n";
print "Avg deltaT = ".($stats{deltaT}/$stats{revs})."\n";
exit(0);

sub waitForChildren {
    my $s = IO::Select->new(@subprocesses);

    my @ready = $s->can_read(10);
    foreach my $fh (@ready) {
	my $hash = fd_retrieve($fh) || die "can't read $fh";
	$stats{deltaT} += $hash->{deltaT};
	$stats{revs} += $hash->{revs};
	$fh->close();
	@subprocesses = grep { $_ != $fh } @subprocesses;
    }
}


sub wanted {
    my $file = $File::Find::name;
    return if -d $file;
    return if $file !~ m/\.gz$/;

    while (@subprocesses > 8) {
	waitForChildren();
    }
print "FILE [$file]\n";
    my $pid = open my $fh, "-|";
    die unless defined $pid;
    if ($pid) {
	push @subprocesses, $fh;
	return;		# return in parent
    }

    open(my $gz, "gunzip -c $file |") || die "open($file): $!";
    my (%stats, %revsSeen);
    $stats{deltaT} = 0.0;
    $stats{revs} = 0;
    while (my $line = <$gz>) {
	next if $line =~ m/^Page:/;
	if ($line =~ m/^EditInc\b.*?\brev1:\s+(\d+)\b.*?\bd01:\s+([^ ]+) d02:\s+([^ ]+) d12:\s+([^ ]+)\b.*?n01:\s+(\d+)\s+n12:\s+(\d+)\b.*?t12:\s+(\d+)/) {
	    next if $5 != 1;
	    next if $6 != 1;
	    die "Already seen $1 in file $file?" if exists $revsSeen{$1};
	    $revsSeen{$1} = 1;
	    my $d01 = $2 + 0.0;
	    my $d02 = $3 + 0.0;
	    my $d12 = $4 + 0.0;
	    next if $d01 == 0.0;
	    next if $d02 != 0.0;
	    my $quality = ($d02 - $d12) / $d01;
	    next if $quality > -1.0;
	    my $deltaT = $7;
	    $stats{deltaT} += $deltaT;
	    $stats{revs}++;
	}
    }
    $gz->close();

#    print "Here comes the data.\n";
#    print "DATA\n";
    store_fd(\%stats, \*STDOUT) || die "can't store result";

    exit(0);
}


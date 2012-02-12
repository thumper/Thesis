#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Find;
use File::Basename;

my $opts = {
  buckets => 'buckets',
};
GetOptions($opts, "buckets=s");

my $s = readConfig();
my $servers = {
    all => $s,
    byPid => {},
};
die "No servers defined" if @{$servers->{all}} == 0;
my $files = findTasks($opts);
# sort the files from smallest to largest
@$files = sort { $a->{size} <=> $b->{size} } @$files;
while (@$files > 0) {
  my $server = getAvailServer($servers);
  my $host = $server->{host};
  my $task = undef;
  if ($host eq 'localhost') {
    $task = pop @$files;
  } else {
    $task = shift @$files;
  }
  my $left = scalar(@$files);
  warn "There are $left files left.\n";
  do_sorting($opts, $servers, $server, $task->{name});
  last if -f ".stop";
}
print "All done\n";
exit(0);
while (scalar(keys %{$servers->{byPid}}) > 0) {
    my @left = keys %{ $servers->{byPid} };
    my $left = scalar(@left);
    warn "There are $left servers left: ".join(', ', @left)."\n";
    waitForServer($servers);
}
exit(0);

sub readConfig {
    my $servers = [];
    while (<>) {
	chomp;
	next if $_ eq '';
	next if m/^\s*#/;
	my ($host, $dir) = split(' ', $_, 2);
	push @$servers, { host => $host, dir => $dir };
    }
    return $servers;
}

sub findTasks {
    my $opts = shift @_;

    my @tasks;

    my $wanted = sub {
	return if !-f $File::Find::name;
	return if $File::Find::name !~ m/\.bkt$/;
	my $sorted = $File::Find::name . ".sorted";
        my $size_orig = -s $File::Find::name;
        my $size_sorted = -s $sorted;
	return if -f $sorted && ($size_orig != $size_sorted);
	push @tasks, { name => $File::Find::name, size => $size_orig };
    };
    find({ wanted => $wanted, follow_fast => 1, no_chdir => 1 },
	$opts->{buckets});
    return \@tasks;
}

sub waitForServer {
    my $servers = shift @_;

    return if scalar(keys %{ $servers->{byPid} }) == 0;
    my $pid = waitpid(-1, 0);
    my $server = delete $servers->{byPid}->{$pid};
    die "Unknown child $pid" if !defined $server;
    die "Child $pid failed to execute" if ($? == -1);
    die "Child $pid exited with signal ".($? & 127) if ($? & 127);
    die "Child $pid exited non-zero" if ($? >> 8) != 0;
    push @{ $servers->{all} }, $server;
}

sub getAvailServer {
    my $servers = shift @_;
    while (@{ $servers->{all} } == 0) {
	waitForServer($servers);
    }
    return pop @{ $servers->{all} };
}

sub do_sorting {
    my $opts = shift @_;
    my $servers = shift @_;
    my $server = shift @_;
    my $file = shift @_;

    my $host = $server->{host};
    my $dir = $server->{dir};
    die "Bad dir [$dir]" if !$dir;
    my $pid = fork();
    if ($pid) { # parent process
	print "$pid: $file ==> $host\n";
	$servers->{byPid}->{$pid} = $server;
	return;
    }
    # child process
    my $file_orig = $file;
    my $file_sorted = $file . ".sorted";

    my $base_orig = basename($file_orig);
    my $base_sorted = basename($file_sorted);

    my $cmd = "cd $dir; sort -n -k 2,2 -T $dir";
    my $cleanup = "cd $dir; rm -f splits/$base_orig splits/$base_sorted";

    my $cphost = "$host:";
    if ($host ne 'localhost') {
      system("rsync -a $file $host:$dir/splits/$base_orig") == 0
	or die "system(rsync1\@$host) failed: $?";
      $cmd = "ssh $host '$cmd splits/$base_orig > splits/$base_sorted'";
      $cleanup = "ssh $host '$cleanup'";
    } else {
      $cphost = '';
      $cmd .= "$file_orig > $file_sorted";
    }
    system($cmd) == 0
	or die "system(cmd: $cmd) failed: $?";
    if ($host ne 'localhost') {
      system("rsync -a $cphost$dir/stats/$base_sorted $file_sorted") == 0
        or die "system(rsync2\@$host) failed: $?";
    }
    system($cleanup) == 0
	or die "system(cmd: $cleanup) failed: $?";
    exit(0);
}

#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Find;
use File::Basename;

my $opts = {
  'splits' => 'split_wiki',
  stats => 'stats',
};
GetOptions($opts, "splits=s", "stats=s");

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
  my $task = undef;
  if ($server eq 'localhost') {
    $task = pop @$files;
  } else {
    $task = shift @$files;
  }
  printf "working on %s, size=%d\n", $task->{name}, $task->{size};
  do_stats($opts, $servers, $server, $task->{name});
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
	return if $File::Find::name !~ m/\.gz$/;
	my $stat = $File::Find::name;
	$stat =~ s/$opts->{splits}/$opts->{stats}/;
	$stat =~ s/xml/stats/;
	return if -f $stat;
        my $size = -s $File::Find::name;
	push @tasks, { name => $File::Find::name, size => $size };
    };
    find({ wanted => $wanted, follow_fast => 1, no_chdir => 1 },
	$opts->{splits});
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

sub do_stats {
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
    my $basefile = basename($file);

    my $statfile = $file;
    $statfile =~ s/$opts->{splits}/$opts->{stats}/;
    $statfile =~ s/xml/stats/;
    my $basestat = basename($statfile);

    my $vandalfile = $statfile;
    $vandalfile =~ s/\.stats\.gz$/.vandalrep/;
    my $basevandal = basename($vandalfile);

    my $cmd = "cd $dir; ./cmds/evalwiki -compute_stats "
      ."-n_edit_judging 10 -n_text_judging 10 -do_text -d ./stats ";
    my $cleanup = "cd $dir; rm -f splits/$basefile "
      ."stats/$basestat stats/$basevandal";

    my $cphost = "$host:";
    if ($host ne 'localhost') {
      system("rsync -a $file $host:$dir/splits/$basefile") == 0
	or die "system(rsync1\@$host) failed: $?";
      $cmd = "ssh $host '$cmd splits/$basefile'";
      $cleanup = "ssh $host '$cleanup'";
    } else {
      $cphost = '';
      $cmd .= $file;
    }
    system($cmd) == 0
	or die "system(cmd: $cmd) failed: $?";
    system("rsync -a $cphost$dir/stats/$basestat $statfile") == 0
	or die "system(rsync2\@$host) failed: $?";
    system("rsync -a $cphost$dir/stats/$basevandal $vandalfile") == 0
	or die "system(rsync3\@$host [$basevandal] [$vandalfile]) failed: $?";
    system($cleanup) == 0
	or die "system(cmd: $cleanup) failed: $?";
    exit(0);
}

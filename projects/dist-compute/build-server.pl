#!/usr/bin/perl

use strict;
use warnings;


while (<>) {
  chomp;
  my ($host, $dir) = split(' ');
  do_build($host, $dir);
}

sub do_build {
  my ($host, $dir) = @_;
  system("ssh $host 'mkdir -p $dir'") == 0
    or die "system(ssh1\@$host) failed: $?";
  system("rsync -a new-server.mk $host:$dir/") == 0
    or die "system(rsync1\@$host) failed: $?";
  system("ssh -t $host 'cd $dir; make -f new-server.mk WORKDIR=`pwd`'") == 0
    or die "system(ssh2\@$host) failed: $?";
}

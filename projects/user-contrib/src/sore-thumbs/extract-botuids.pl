#!/usr/bin/perl

$/ = "\r";

while (<>) {
    my ($uid, $username) = split(' ', $_, 2);
    next if $username =~ m/talbot/i;
    next if $username =~ m/chabot/i;
    print $uid, "\n";
}

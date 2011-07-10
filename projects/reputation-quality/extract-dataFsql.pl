#!/usr/bin/perl

use strict;
use warnings;
use Date::Manip;
use File::Find;
use lib '../edit-quality/lib';
use PAN;

my ($revids, $sqldir) = @ARGV;

my $panrevs = {};

readCSV($revids, [0, 1, 2, 3], sub {
    my ($revid, $t, $author, $class) = @_;
    $panrevs->{$revid} = { 'time' => $t, author => $author,
			    class => $class };
});

find({ wanted => \&wanted, no_chdir=>1 }, $sqldir);

exit(0);

sub wanted {
  my $file = $File::Find::name;
  return if -d $file;
  return if $file !~ m/\.sql$/;

  my $in_revision = 0;
  my $prevline = '';
  open(my $fh, "<$file") || die "open($file): $!";
  while (<$fh>) {
    chomp;
    if (m/^INSERT INTO wikitrust_page\b/) {
      $prevline = '';
      $in_revision = 0;
      next;
    }
    if (m/^INSERT INTO wikitrust_revision\b/) {
      $in_revision = 1;
    }
    next if !$in_revision;
    # clean up the line
    s/^.*\bVALUES\s+//;
    s/^,\s+//;
    if (m/;$/) {
      # we'll be onto a new statement, next line.
      $in_revision = 0;
    }
    s/\s*;$//;
    next if $_ eq '';
    if (m/\( (?<RevId> \d+),\s* /x) {
      if (exists $panrevs->{ $+{RevId} }) {
	my %row = %{ parseLine($file, $_) };
	my %prevrow = %{ parseLine($file, $prevline) };
	# Figure out the features
	$row{PrevSameAuthor} = isSameAuthor(\%prevrow, \%row);
	my $curTime = ParseDate( $row{TimeString} );
	my $prevTime = ParseDate( $prevrow{TimeString} );
	my $curTimeSec = UnixDate($curTime, "%s");
	my $prevTimeSec = UnixDate($prevTime, "%s");

	$row{LogtimePrev} = log(1 + abs($curTimeSec - $prevTimeSec));
	$row{HourOfDay} = get_hours($row{TimeString});

	$row{Delta} = get_element($row{QualityInfo}, "delta");

	my @hist = split(' ', get_element($row{QualityInfo},
		"word_trust_histogram"));
	my $cur_length = 0;
	foreach my $n (0..9) {
	    $row{"Hist$n"} = $hist[$n];
	    $cur_length += $hist[$n];
	}
	$row{LogLength} = log(1.0 + $cur_length);

	my @prevhist = split(' ', get_element($prevrow{QualityInfo},
		"word_trust_histogram"));
	my $prev_length = 0;
	foreach my $n (0..9) {
	    $prev_length += $prevhist[$n];
	}
	$row{LogPrevLength} = log(1.0 + $prev_length);

	foreach my $n (0..9) {
	    $row{"PPrevHist$n"} = $prevhist[$n] / (1.0 + $prev_length);
	    my $d = $hist[$n] - $prevhist[$n];
	    my $log_d = 0.0;
	    if ($d > 0) {
		$log_d = log(1 + $d);
	    } elsif ($d < 0) {
		$log_d = - log(1 - $d);
	    }
	    $row{"LDeltaHist$n"} = $log_d;
	}

	# TODO: print out line

	$prevline = $_;
      } else {
	$prevline = $_;
      }
    } else {
      die "file $file, no revid: $_";
    }
  }
  close($fh);

  exit(0);
}

sub parseLine {
  my $file = shift @_;
  my $_ = shift @_;

  # Full regex for parsing a wikitrust_revision entry.
  if (m/\(
      (?<RevId> \d+),\s*
      (?<PageId> \d+),\s*
      (?<TextId> \d+),\s*
      '(?<TimeString> \d+)',\s*
      (?<UserId> \d+),\s*
      '(?<UserName> .*?)',\s*
      \d+,\s*
      '(?<QualityInfo> .*?)',\s*
      \d+,\s*
      (?<ReputationDelta> [^,]+),\s*
      (?<OverallTrust> [^,]+),\s*
      (?<OverallQuality> [^,]+)\s*
      \)
      /x)
  {
    my %row = %+;
    return \%row;
  } else {
    die "Line from $file didn't match: $_"
  }
}

sub isSameAuthor {
  my ($prev, $cur) = @_;
  return 0 if $prev->{UserId} != $cur->{UserId};
  return 0 if $prev->{UserId} == 0 && $prev->{UserName} ne $cur->{UserName};
  return 1;
}

sub get_hours {
  my $timestr = shift @_;

  my $h = substr($timestr, 8, 2);
  my $m = substr($timestr, 10, 2);
  my $s = substr($timestr, 12, 2);
  return $h + ($m / 60.0) + ($s / 3600.0);
}

sub get_element {
  my ($info, $name) = @_;
  my $i = index($info, $name) + length($name) + 1;
  my $j = index($info, ")", $i);
  return substr($info, $i, $j - $i);
}



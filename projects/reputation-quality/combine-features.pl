#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use XML::Simple;
use List::Util qw( min max );
use lib 'lib';
use PAN;
use Carp;
use Getopt::Long;

my $debug = 0;
GetOptions("debug" => \$debug);

my ($panfile, $repfile, $datafile) = @ARGV;

my $panrevs = {};

readCSV($panfile, [0, 3], sub {
  }, sub {
    my ($revid, $class) = @_;
    $panrevs->{$revid} = { class => $class };
  });

my $reps = {};
readCSV($repfile, [1..4], sub {
  }, sub {
    my ($revid, $rep, $repbin, $class) = @_;
    my $expected_class = $panrevs->{$revid}->{class};
    die "Bad class detected: $class, $expected_class"
      if $class ne $expected_class;
    $reps->{$revid} = { rep => $rep, bin => $repbin };
  });

warn "There are ".scalar(keys(%$panrevs))." PAN revs\n";
warn "There are ".scalar(keys(%$reps))." rep revs\n";

print "\@relation wikitrust\n";
do {
  my $hdr_row = [];             # list of header strings
  my $hdr_index = {};           # what position a header is in the list
  my $booleans = {};            # headers which are boolean
  foreach my $b qw(anon next_anon prev_same_author next_same_author comment_revert next_comment_revert vandalism) {
    $booleans->{$b} = 1;
  }

  my $skip_cols = {};            # cols to skip printing
  foreach my $c qw(reputation vandalism comment_revert prev_same_author overall_trust log_length log_prev_length) {
    $skip_cols->{$c} = 1;
  }

  my $revid_col = undef;

  readCSV($datafile, undef, sub {
      # Print out the rest of the ARFF header
      $hdr_row = shift @_;
      for (my $i = 0; $i < scalar(@$hdr_row); $i++) {
        $hdr_index->{$hdr_row->[$i]} = $i;

        my $hdr = $hdr_row->[$i];
        next if exists $skip_cols->{$hdr};

        print "\@attribute $hdr ";
        print (exists $booleans->{$hdr} ? "{false,true}" : "numeric");
        print "\n";
      }

      $revid_col = $hdr_index->{newid};
      die "Bad column spec" if !defined $revid_col;

#      print "\@attribute Reputation numeric\n";
      #print "\@attribute RepBin numeric\n";
      print "\@attribute Vandalism {false,true}\n";
      print "\@data\n";
    }, sub {
      # Only print PAN2010 data
      my $revid = $_[ $revid_col ];
      return if !exists $panrevs->{$revid};

      # Print a row of data


      foreach my $col (@$hdr_row) {
        next if exists $skip_cols->{$col};

        my $col_idx = $hdr_index->{$col};
        print $_[ $col_idx ], ",";
      }

#      print $reps->{$revid}->{rep}, ",";
      #print $reps->{$revid}->{bin}, ",";

      my $true_class = $panrevs->{$revid}->{class} eq 'vandalism' ? 'true' : 'false';
      my $wt_class = $_[ $hdr_index->{vandalism} ];

      warn "Bad WT class for revid $revid: wt=$wt_class, pan=$true_class"
        if $true_class ne $wt_class;

      print $true_class, "\n";
    });
};

exit(0);


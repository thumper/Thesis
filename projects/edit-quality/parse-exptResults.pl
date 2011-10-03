#!/usr/bin/perl

use strict;
use warnings;
use Error qw(:try);
use Switch;
use List::Util qw(sum);
use constant EDITOUT => 1;
use constant EDITSHOUT => 2;
use constant TEXTOUT => 3;
use constant TEXTSHOUT => 4;

my $base = $ARGV[0];
open(my $editout, ">$base-table-editlong.tex") || die "open(editlong): $!";
open(my $textout, ">$base-table-textlong.tex") || die "open(textlong): $!";
open(my $editshout, ">$base-table-editlong-short.tex")
    || die "open(editlong-short): $!";
open(my $textshout, ">$base-table-textlong-short.tex")
    || die "open(textlong-short): $!";

my (%textcache, %textshcache, %editshcache);
my (@editout, @textout, @editshout, @textshout);
my (%runtimes, %editlongbyed);
my $expt = undef;

try {
  while (<>) {
    try {
      die "Error detected" if m/traceback/i;
      chomp;
      if (m/^\+ doexpt /) {
	writeExpt($expt);
	$expt = parseExpt($_);
      }
      if (!defined $expt) {
	# skip
      } elsif (m/^TOTAL TRIANGLES/) {
	$expt->{tri_tot} = parseTriangles();
      } elsif (m/^BAD TRIANGLES/) {
	$expt->{tri_bad} = parseTriangles();
      } elsif (m/^\+ wc perf/) {
	parseSetSize($expt);
      } elsif ($_ eq 'EDITLONG') {
	parsePerf($expt, 'edit');
      } elsif ($_ eq 'TEXTLONG') {
	parsePerf($expt, 'text');
      } elsif (m/^COMPUTING THE STATISTICS/) {
	$expt->{timing} = parseCPUTime();
      } elsif (m/^new max heap: \d+/) {
	parseHeapInfo($expt, $_);
      }
    } otherwise {
      warn $@;
      if (defined $expt) {
	$expt->{diff} ||= 'NA';
	$expt->{mq} ||= 'NA';
	$expt->{editdist} ||= 'NA';
	my $key = "d".$expt->{diff}."mq".$expt->{mq}."ed".$expt->{editdist};
	warn "Skipping $key\n";
      }
      $expt = undef;
    };
  }
  writeExpt($expt);
} otherwise {
  warn $@;
};
foreach my $tuple ([\@editout, $editout, EDITOUT],
		  [\@textout, $textout, TEXTOUT],
		  [\@editshout, $editshout, EDITSHOUT],
		  [\@textshout, $textshout, TEXTSHOUT])
{
  my ($array, $fh, $type) = @$tuple;
  my @sorted = sort { $b->[0] <=> $a->[0] } @$array;
  my $lines = 0;
  my $tablenum = 'A';
  writeHeader($type, $lines);
  foreach (@sorted) {
    $lines++;
    if ($lines >= 25) {
      writeFooter($type, $tablenum);
      writeHeader($type, $lines);
      $lines = 0;
      $tablenum++;
    }
    print $fh $_->[1];
  }
  writeFooter($type, $tablenum, 1);
}
close($editout);
close($editshout);
close($textout);
close($textshout);

generateRuntimeTable();
generateEditlongByED();

exit(0);

sub generateRuntimeTable {
  # Compute mean of runtimes and generate
  # an abbreviated table for editlong comparison
  my (%avgtime, %stddev);
  foreach my $diff (keys %runtimes) {
    my $array = $runtimes{$diff};
    my $sum = sum @$array;
    my $elems = scalar(@$array);
    my $avgtime = $sum / $elems;
    $avgtime{$diff} =  $avgtime;
    my @diffs = map { ($_- $avgtime) * ($_ - $avgtime) } @$array;
    my $avgdiff = (sum @diffs) / $elems;
    $stddev{$diff} = sqrt($avgdiff);
    # warn "diff$diff: ".join(", ", @$array)."\n";
  }
  open(my $diffout, ">$base-table-timing.tex")
    || die "open(timing): $!";
  print $diffout <<'EOF';
\begin{table}[tbph]
\begin{center}
\begin{tabular}{|c||c|c|}
\hline
Diff & Avg Run Time & Std Dev RT  \\
\hline
\hline
EOF
  foreach my $diff (sort { $avgtime{$a} <=> $avgtime{$b} } keys %runtimes) {
    my $line = sprintf "diff%d & %dm & %0.2fm \\\\\n", $diff,
      $avgtime{$diff}, $stddev{$diff};
    print $diffout $line;
  }
  print $diffout <<'EOF';
\hline
\end{tabular}
\end{center}
\caption[Average running time of difference algorithms]
  {Average running time of difference algorithms.}
\label{tab:difftiming}
\end{table}
EOF
  close($diffout);
}

sub generateEditlongByED {
  open(my $out, ">$base-table-editlongbyed.tex")
    || die "open(editlongbyed): $!";
  foreach my $ed (sort { $b <=> $a } keys %editlongbyed) {
    print $out <<'EOF';
\begin{table}[tbph]
\begin{center}
\begin{tabular}{|c|c||c|}
\hline
Diff & MatchQuality & PR-AUC  \\
\hline
\hline
EOF
  my $cmpfunc = sub {
    my @afields = split(/,/, $a);
    my @bfields = split(/,/, $b);
    my $cmp = $bfields[0] <=> $afields[0];
    $cmp = $bfields[0] cmp $afields[0] if $cmp == 0;
    return $cmp;
  };
  foreach my $apr (sort $cmpfunc keys %{ $editlongbyed{$ed} }) {
    my $record = $editlongbyed{$ed}->{$apr};
    my $line = sprintf "diff%d & mq%s & %0.3f\\%% \\\\\n",
      $record->{diff},
      join('', sort keys %{ $record->{mq} }),
      $record->{APR} * 100.0;
    print $out $line;
  }
    print $out <<EOF;
\\hline
\\end{tabular}
\\end{center}
\\caption[Comparison of diff algorithms using edit distance \\textbf{ed$ed}]{
  Performance of difference algorithms for
  edit distance \\textbf{ed$ed}.  Where multiple match
  quality functions resulted in the same performance, they
  have been grouped together.}
\\label{tab:editlongbyed$ed}
\\end{table}
EOF
  }
  close($out);
}

sub commify {
    my $result = "N/A";
    my $unit = $_[1] || "";
    if (defined $_[0]) {
	my $text = reverse $_[0];
	$text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	$result =  scalar reverse $text;
    }
    return $result;
}

sub writeHeader {
  my $file = shift @_;
  my $lines = shift @_;
  switch ($file) {
  case TEXTOUT {
    print $textout <<'EOF';
\begin{table}[tbph]
\begin{center}
\begin{tabular}{|c|c|c||c|c|c|}
\hline
Diff & Match Quality & Edit Distance & PR-AUC & ROC-AUC & Num Revs \\
\hline
\hline
EOF
  }
  case EDITOUT {
    print $editout <<'EOF';
\begin{landscape}
    \begin{longtable}{|c|c|c|c||c|c||c|c|c|c|}
\hline
 &  & Match & Edit
        & ROC & PR
        & Num & Run
        & Total & Bad
	& Heap & Memory \\
Diff & Precise & Quality & Dist
        & AUC & AUC
        & Revs & Time
        & Triangles & Triangles
	& Size & Usage \\
\hline
\hline
\endhead
EOF
  }
  case TEXTSHOUT {
    print $textshout <<'EOF';
\begin{table}[tbph]
\begin{center}
\begin{tabular}{|c||c|c|}
\hline
Match Quality & PR-AUC & ROC-AUC \\
\hline
\hline
EOF
  }
  case EDITSHOUT {
    return if $lines != 0;
    print $editshout <<'EOF';
\begin{landscape}
  \begin{longtable}{|c|c|c||c|c||c|c|c|c|}
\hline
Diff & Match Quality & Edit Dist
        & PR-AUC & ROC-AUC
        & Num Revs & Run Time
        & Total Triangles & Bad Triangles \\
\hline
\hline
\endhead
\hline
\endfoot
EOF
  }
  };
}

sub writeFooter {
  my $type = shift @_;
  my $counter = shift @_;
  my $last = shift @_ || 0;
  switch ($type) {
  case TEXTOUT {
    print $textout <<'EOF';
\hline
\end{tabular}
\end{center}
\caption[Text longevity using differen match qualities]]
    {Comparison of text longevity performance using
    multiple difference algorithms, sorted by PR-AUC.}
\end{table}
EOF
  }
  case EDITOUT {
    print $editout <<'EOF';
\hline
\caption{Comparison of edit longevity performance,
    sorted by PR-AUC.}
\end{longtable}
\end{landscape}
\clearpage
EOF
  }
  case TEXTSHOUT {
    print $textshout <<EOF;
\\hline
\\end{tabular}
\\end{center}
\\caption{Comparison of text longevity performance using
    multiple match quality functions, sorted by PR-AUC.}
\\label{tab:textshout$counter}
\\end{table}
EOF
  }
  case EDITSHOUT {
    return if $last != 1;
    print $editshout <<EOF;
\\hline
  \\caption{Comparison of edit longevity performance,
    sorted by PR-AUC.}
  \\label{tab:editshout$counter}
  \\end{longtable}
\\end{landscape}
\\clearpage
EOF
  }
  };
}

sub recordEditlongByED {
    my $expt = shift @_;

    my $ed = $expt->{editdist};
    my $d = $expt->{diff};
    my $mq = $expt->{mq};
    my $apr = $expt->{edit}->{APR};

    $editlongbyed{$ed} = {} if !exists $editlongbyed{$ed};
    $editlongbyed{$ed}->{"$apr,$d"} = {}
      if !exists $editlongbyed{$ed}->{"$apr,$d"};
    my $record = $editlongbyed{$ed}->{"$apr,$d"};
    if (!exists $record->{diff}) {
      $record->{diff} = $d;
      $record->{mq} = {};
      $record->{APR} = $apr;
    }

    ## Diffs 8 and 4, and 5 and 3 turn out to be the same.
    ## This code caught that similarity.
    #die "Exactly the same APR but bad diff $d and ".$record->{diff}
    #  if $record->{diff} != $d;

    $record->{mq}->{$mq} = 1;
}

sub writeExpt {
    my $expt = shift @_;
    return if !defined $expt;

    my $key = "d".$expt->{diff}."mq".$expt->{mq}."ed".$expt->{editdist};
    # if we don't have a complete record, just skip it.
    die "bad record: $key\n" if !defined $expt->{tri_bad};

    # Build data for running time table
    $runtimes{$expt->{diff}} = [] if !exists $runtimes{$expt->{diff}};
    push @{ $runtimes{$expt->{diff}} }, $expt->{timing};

    recordEditlongByED($expt);

    # EDIT LONG
    my $val = sprintf 'diff%d & %s & mq%d & ed%d & %0.3f\\%% & %0.3f\\%% & %s & %dm & %s & %s & %s & %s \\\\'."\n",
	$expt->{diff}, $expt->{precise}, $expt->{mq}, $expt->{editdist},
	$expt->{edit}->{ROC} * 100.0, $expt->{edit}->{APR} * 100.0,
	commify($expt->{edit}->{size}),
	$expt->{timing},
	commify($expt->{tri_tot}), commify($expt->{tri_bad}),
	commify($expt->{heaplen}), commify($expt->{maxmem}, "MB");
    push @editout,
	[Tuple->new(
	  $expt->{edit}->{APR},
	  $expt->{diff}, $expt->{mq}, $expt->{editdist}
	), $val];


    # TEXT LONG
    $val = sprintf 'diff%d & mq%d & ed%d & %0.3f\\%% & %0.3f\\%% & %s \\\\'."\n",
	$expt->{diff}, $expt->{mq}, $expt->{editdist},
	$expt->{text}->{APR} * 100.0,
	$expt->{text}->{ROC} * 100.0,
	commify($expt->{text}->{size});
    if (exists $textcache{$key}) {
        die "text: conflicting data:\n"
	    ."1: $textcache{$key}\n2: $val\nfor key $key"
	    if $textcache{$key} ne $val;
    } else {
      $textcache{$key} = $val;
      push @textout,
	[Tuple->new(
	  $expt->{edit}->{APR},
	  $expt->{diff}, $expt->{mq}, $expt->{editdist}
	), $val];
    }

    return if $expt->{precise} eq 'N';

    # EDIT LONG
    $key = "d".$expt->{diff}."ed".$expt->{editdist}."mq".$expt->{mq};
    $val = sprintf 'diff%d & mq%d & ed%d & %0.3f\\%% & %0.3f\\%% & %s & %dm & %s & %s \\\\'."\n",
	$expt->{diff}, $expt->{mq}, $expt->{editdist},
	$expt->{edit}->{APR} * 100.0,
	$expt->{edit}->{ROC} * 100.0,
	commify($expt->{edit}->{size}),
	$expt->{timing},
	commify($expt->{tri_tot}), commify($expt->{tri_bad});
    if (exists $editshcache{$key}) {
	my $dist = distance($val, $editshcache{$key});
        die "edit conflicing data of distance $dist:\n"
	    . "1: $editshcache{$key}\n2: $val\nfor key $key"
	    if ($editshcache{$key} ne $val)
		&& ($dist > 10);
	return;
    }
    $editshcache{$key} = $val;
    push @editshout,
      [Tuple->new(
	$expt->{edit}->{APR},
	$expt->{diff}, $expt->{mq}, $expt->{editdist}
      ), $val];

    # TEXT LONG
    $key = "mq".$expt->{mq};
    $val = sprintf 'mq%d & %0.3f\\%% & %0.3f\\%% \\\\'."\n",
	$expt->{mq},
	$expt->{text}->{APR} * 100.0,
	$expt->{text}->{ROC} * 100.0;
    if (exists $textshcache{$key}) {
        die "conflicing textlong data:\n1: $textshcache{$key}\n2: $val\nfor key $key"
	    if $textshcache{$key} ne $val;
	return;
    }
    $textshcache{$key} = $val;
    push @textshout,
      [Tuple->new(
	$expt->{text}->{APR},
	$expt->{mq}
      ), $val];
}

sub parseExpt {
    my $cmd = shift @_;
    my $expt = {
	diff => 0,
	mq => 0,
	precise => 'N',
	editdist => 0,
	text => {},
	edit => {},
    };
    $cmd =~ s/^\+ doexpt //;
    $cmd =~ s/^'([^\']+)'.*$/$1/;
    my @cmds = split(' ', $cmd);
    foreach (@cmds) {
	if (m/^diff=(\d)\b/) {
	    $expt->{diff} = $1+0;
	} elsif (m/^precise$/) {
	    $expt->{precise} = 'Y';
	} elsif (m/^match-quality=(\d)\b/) {
	    $expt->{mq} = $1+0;
	} elsif (m/^edist=(\d)\b/) {
	    $expt->{editdist} = $1+0;
	} elsif (m/^'/) {
	    last;
	} else {
	    die "Unknown cmd: $_, line=$cmd";
	}
    }
    return $expt;
}

sub parseTriangles {
    while (<>) {
	die "Error detected" if m/traceback/i;
	next if m/^\+/;
	chomp;
	return $_ + 0 if m/^\d+$/;
    }
    die "Unexpected end of triangle input";
}

sub parseSetSize {
    my $expt = shift @_;
    return if !defined $expt;
    my $c = 0;
    while (<>) {
	die "Error detected" if m/traceback/i;
	chomp;
	my @f = split(' ', $_);
        if ($f[3] eq 'perf-editlong.txt') {
	    $expt->{edit}->{size} = $f[0];
	    $c++;
	}
        if ($f[3] eq 'perf-textlong.txt') {
	    $expt->{text}->{size} = $f[0];
	    $c++;
	}
	return if $c == 2;
    }
    die "EOF on set size";
}

sub parseHeapInfo {
    my ($expt, $line) = @_;
    return if !defined $expt;
    return if $line =~ m/List of/;
    my $heaplen = 0;
    my $maxmem = 0;
    if (m/^new max heap:\s+(\d+)/) {
	$heaplen = 0+$1;
	$expt->{heaplen} = $heaplen if $heaplen > ($expt->{heaplen} || 0);
    }
    my $start = $.;
    while (<>) {
	return if m/List of/;	    # early msg from next program
	die "Error detected" if m/traceback/i;
	chomp;
	if (m/^debug: kbytes = (\d+)/) {
	    my $found = $.;
	    my $dist = $found - $start;
	    if ($dist > 7) {
	      warn "crazy: debug distance is $dist";
	      die "Crazy: the debug line is too far at $dist lines";
	    }
	    $maxmem = (0 + $1) / 1024.0;
	    $maxmem = int($maxmem + 0.5);
	    $expt->{maxmem} = $maxmem if $maxmem > ($expt->{maxmem} || 0);
	    return;
	}
    }
    die "EOF on heap info";
}

sub parsePerf {
    my $expt = shift @_;
    my $type = shift @_;
    return if !defined $expt;
    my $c = 0;
    while (<>) {
	die "Error detected" if m/traceback/i;
	chomp;
	if (m/^APR\s/) {
	    my @f = split(' ');
	    $expt->{$type}->{APR} = $f[1];
	    $c++;
	} elsif (m/^ROC\s/) {
	    my @f = split(' ');
	    $expt->{$type}->{ROC} = $f[1];
	    $c++;
	}
	return if $c == 2;
    }
    die "EOF on perf";
}

sub parseCPUTime {
    my $total = 0.0;
    while (<>) {
	die "Error detected" if m/traceback/i;
	chomp;
	if (m/^user\s+(\d+)m(\d+)/) {
	    $total += $1 * 60 + $2;
	} elsif (m/^sys\s+(\d+)m(\d+)/) {
	    $total += $1 * 60 + $2;
	    # sys comes last, so clean and finish
	    $total /= 60.0;
	    return int($total + 0.5);
	}
    }
    die "EOF on cputime";
}

sub distance {
  my ($a, $b) = @_;
  my $len = (length($a) < length($b)) ? length($b) : length($a);
  my $dist = 0;
  for (my $i = 0; $i < $len; $i++) {
    my $d = ord(substr($a, $i, 1)) - ord(substr($b, $i, 1));
    warn "@ $i, d = $d\n" if $d != 0;
    $dist += abs($d);
  }
  return $dist;
}

package Tuple;
use strict; use warnings;
use overload '<=>' => \&mycompare;

sub new {
  my $class = shift @_;
  my $values = [ @_ ];
  bless $values, $class;
}

sub mycompare {
  my ($a, $b, $order) = @_;
  my $i = 0;
  my $scale = 1;
  $scale = -1 if $order;
  while ($i < scalar(@$a)) {
    my $cmp = ($a->[$i] <=> $b->[$i]);
    return ($scale * $cmp) if $cmp != 0;
    $i++;
  }
  return 0;
}


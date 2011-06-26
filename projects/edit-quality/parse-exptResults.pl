#!/usr/bin/perl

use strict;
use warnings;
use Error qw(:try);

open(my $editout, ">expt.out-table-editlong.tex") || die "open(editlong): $!";
open(my $textout, ">expt.out-table-textlong.tex") || die "open(textlong): $!";
open(my $editshout, ">expt.out-table-editlong-short.tex")
    || die "open(editlong-short): $!";
open(my $textshout, ">expt.out-table-textlong-short.tex")
    || die "open(textlong-short): $!";
writeHeader();

my (%textcache, %textshcache, %editshcache);
my (@editout, @textout, @editshout, @textshout);
my $expt = undef;

try {
  while (<>) {
    die "Error detected" if m/traceback/i;
    chomp;
    if (m/^\+ doexpt /) {
	writeExpt($expt);
	$expt = parseExpt($_);
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
    } elsif (m/^new max heap:/) {
	parseHeapInfo($expt, $_);
    }
  }
  writeExpt($expt);
} otherwise { 
  warn $@;
  foreach my $pair ([\@editout, $editout], [\@textout, $textout],
		    [\@editshout, $editshout], [\@textshout, $textshout])
  {
    my ($array, $fh) = @$pair;
    my @sorted = sort { $b->[0] <=> $a->[0] } @$array;
    foreach (@sorted) {
	print $fh $_->[1];
    }
  }
  writeFooter();
};
close($editout);
close($editshout);
close($textout);
close($textshout);
exit(0);

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
    print $textout <<'EOF';
\begin{table}[tbph]
\begin{center}
\begin{tabular}{|c|c||c|c|c|}
\hline
Diff & Match Quality & ROC AUC & Mean Prec. & Num Revs \\
\hline
\hline
EOF
    print $editout <<'EOF';
\begin{sidewaystable}[!tp]
  \begin{center}
    \begin{tabular}{|c|c|c|c||c|c||c|c|c|c|}
\hline
 &  & Match & Edit 
        & ROC & Mean
        & Num & Run
        & Total & Bad
	& Heap & Memory \\
Diff & Precise & Quality & Dist
        & AUC & Prec.
        & Revs & Time
        & Triangles & Triangles
	& Size & Usage \\
\hline
\hline
EOF
    print $textshout <<'EOF';
\begin{table}[tbph]
\begin{center}
\begin{tabular}{|c|c||c|c|c|}
\hline
Diff & Match Quality & ROC AUC & Mean Prec. & Num Revs \\
\hline
\hline
EOF
    print $editshout <<'EOF';
\begin{sidewaystable}[!tp]
  \begin{center}
    \begin{tabular}{|c|c|c||c|c||c|c|c|c|}
\hline
Diff & Match Quality & Edit Dist
        & ROC AUC & Mean Prec.
        & Num Revs & Run Time
        & Total Triangles & Bad Triangles \\
\hline
\hline
EOF
}

sub writeFooter {
    print $textout <<'EOF';
\hline
\end{tabular}
\end{center}
\caption{Comparison of text longevity performance using
    multiple difference algorithms.}
\end{table}
EOF
    print $editout <<'EOF';
\hline
\end{tabular}
\end{center}
\caption{Comparison of edit longevity performance using
    varying parameters.}
\end{sidewaystable}
EOF
    print $textshout <<'EOF';
\hline
\end{tabular}
\end{center}
\caption{Comparison of text longevity performance using
    multiple difference algorithms.}
\end{table}
EOF
    print $editshout <<'EOF';
\hline
\end{tabular}
\end{center}
\caption{Comparison of edit longevity performance using
    varying parameters.}
\end{sidewaystable}
EOF
}

sub writeExpt {
    my $expt = shift @_;
    return if !defined $expt;

    # EDIT LONG
    my $val = sprintf 'diff%d & %s & mq%d & ed%d & %0.3f\\%% & %0.3f\\%% & %s & %dm & %s & %s & %s & %s \\\\'."\n",
	$expt->{diff}, $expt->{precise}, $expt->{mq}, $expt->{editdist},
	$expt->{edit}->{ROC} * 100.0, $expt->{edit}->{APR} * 100.0,
	commify($expt->{edit}->{size}),
	$expt->{timing},
	commify($expt->{tri_tot}), commify($expt->{tri_bad}),
	commify($expt->{heaplen}), commify($expt->{maxmem}, "MB");
    push @editout, [$expt->{edit}->{APR} || 0.0, $val];


    # TEXT LONG
    my $key = "d".$expt->{diff}."mq".$expt->{mq};
    $val = sprintf 'diff%d & mq%d & %0.3f\\%% & %0.3f\\%% & %s \\\\'."\n",
	$expt->{diff}, $expt->{mq},
	$expt->{text}->{ROC} * 100.0, $expt->{text}->{APR} * 100.0,
	commify($expt->{text}->{size});
    if (exists $textcache{$key}) {
        die "text: conflicing data:\n1: $textcache{$key}\n2: $val\nfor key $key"
	    if $textcache{$key} ne $val;
	return;
    }
    $textcache{$key} = $val;
    push @textout, [$expt->{text}->{APR} || 0.0, $val];

    return if $expt->{precise} eq 'N';

    # EDIT LONG
    $key = "d".$expt->{diff}."ed".$expt->{editdist}."mq".$expt->{mq};
    $val = sprintf 'diff%d & mq%d & ed%d & %0.3f\\%% & %0.3f\\%% & %s & %dm & %s & %s \\\\'."\n",
	$expt->{diff}, $expt->{mq}, $expt->{editdist},
	$expt->{edit}->{ROC} * 100.0, $expt->{edit}->{APR} * 100.0,
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
    push @editshout, [$expt->{edit}->{APR} || 0.0, $val];

    # TEXT LONG
    $key = "d".$expt->{diff}."mq".$expt->{mq};
    $val = sprintf 'diff%d & mq%d & %0.3f\\%% & %0.3f\\%% & %s \\\\'."\n",
	$expt->{diff},
	$expt->{mq},
	$expt->{text}->{ROC} * 100.0, $expt->{text}->{APR} * 100.0,
	commify($expt->{text}->{size});
    if (exists $textshcache{$key}) {
        die "conflicing textlong data:\n1: $textshcache{$key}\n2: $val\nfor key $key"
	    if $textshcache{$key} ne $val;
	return;
    }
    $textshcache{$key} = $val;
    push @textshout, [$expt->{text}->{APR} || 0.0, $val];
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
    my $heaplen = 0;
    my $maxmem = 0;
    if (m/^new max heap:\s+(\d+)/) {
	$heaplen = 0+$1;
	$expt->{heaplen} = $heaplen if $heaplen > ($expt->{heaplen} || 0);
    }
    while (<>) {
	die "Error detected" if m/traceback/i;
	chomp;
	if (m/^debug: kbytes = (\d+) ;/) {
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
    my $c = 0;
    while (<>) {
	die "Error detected" if m/traceback/i;
	chomp;
	if (m/^APR\b/) {
	    my @f = split(' ');
	    $expt->{$type}->{APR} = $f[1];
	    $c++;
	} elsif (m/^ROC\b/) {
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
	if (m/^user\s+(\d+)m(\d+)\b/) {
	    $total += $1 * 60 + $2;
	} elsif (m/^sys\s+(\d+)m(\d+)\b/) {
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


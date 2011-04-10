package MediawikiDump;;
use strict;
use warnings;

use File::Find;
use Carp;

sub new {
    my $class = shift @_;
    my ($page_start, $page_end, $rev) = @_;
    bless {
	page_start => $page_start,
	rev_handler => $rev,
	page_end => $page_end
    }, $class;
}

sub process {
    my ($this, $fileOrDir) = @_;

    croak "File not defined" if !defined $fileOrDir;

    my $handleFile = sub {
	my $file = $_;
	my $fh = openFile($file);
	return if !defined $fh;
	while (!eof($fh)) {
	    $this->readPage($fh, $file);
	}
    };

    if (-d $fileOrDir) {
	find({ wanted => $handleFile, no_chdir => 1 },
		$fileOrDir);
    } else {
	local $_ = $fileOrDir;
	$handleFile->($fileOrDir);
    }
}

sub openFile {
    return undef if -d $_;

    my $file = shift @_;
    my $fh = undef;
    if (m/\.gz$/) {
	open($fh, "gunzip -c $file |") || die "gunzip($file): $!";
    } elsif (m/\.7z$/) {
	open($fh, "7za e -so $file |") || die "7za($file): $!";
    } else {
	open($fh, "<$file") || die "open($file): $!";
    }
    return $fh;
}

sub readPage {
    my ($this, $fh, $file) = @_;

    my $pagehdr = {
	file => $file,
	start => undef,
	end => undef,
	lines => [],
    };
    my $pos = tell($fh);
    my $inpage = 0;
    while (<$fh>) {
	if (m/^\s*<page>/) {
	    $inpage = 1;
	    $pagehdr->{start} = $pos;
	}
	if (m/^\s*<(?:revision|\/page)>/) {
	    confess "Not in page?" if !$inpage;
	    $inpage = 0;
	    $pagehdr->{end} = $pos - 1;
	    push @{ $pagehdr->{lines} }, "</page>\n";
	    $this->{page_start}->($pagehdr);
	    # We only read one page at a time
	    return $this->readRevisions($fh, $file, $pos) if m/<revision>/;
	}
	push @{ $pagehdr->{lines} }, $_ if $inpage;
	$pos = tell($fh);
    }
}

sub readRevisions {
    my ($this, $fh, $file, $pos) = @_;

    # We only get called if the start of a revision was found,
    # so just include that line
    my $rev = {
	file => $file,
	start => $pos,
	end => undef,
	lines => [ "    <revision>\n" ],
    };
    my $inrev = 1;
    while (<$fh>) {
	if (m/^\s*<revision>/) {
	    $inrev = 1;
	    $rev->{start} = $pos;
	}
	$pos = tell($fh);
	if (m/^\s*<\/revision>/) {
	    confess "Not in revision?" if !$inrev;
	    $inrev = 0;
	    $rev->{end} = $pos - 1;
	    push @{ $rev->{lines} }, $_;
	    $this->{rev_handler}->($rev);
	    $rev->{start} = undef;
	    $rev->{end} = undef;
	    $rev->{lines} = [];
	}
	if (m/^\s*<\/page>/) {
	    confess "In revision!" if $inrev;
	    $this->{page_end}->();
	    return;
	}
	push @{ $rev->{lines} }, $_ if $inrev;
    }
}



1;

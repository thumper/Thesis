#!/usr/bin/perl

# Take Luca's splitwiki output, and split further, so that
# there is a single file/directory per article.

use constant SRCDIR => "/export/notbackedup/wikitrust1/enwiki-20080103/";
use constant OUTDIR => "./ensplit-20080103/";

use File::Find;
use IO::Zlib;
use Data::Dumper;
use File::Path qw(mkpath);

find({ wanted => \&wanted, no_chdir=>1 }, SRCDIR);
exit(0);

sub wanted {
    my $file = $File::Find::name;
    next if -d $file;
    my $fh = IO::Zlib->new();
    $fh->open($file, "rb") || die "open: $!";
    findPage($fh);
    $fh->close();
#    my $ref = XMLin($txt);
##    print Dumper($ref);
}

sub findPage {
    my $fh = shift @_;
    return if $fh->eof();
    my $line;
    do {
	$line = $fh->getline();
    } while ($line !~m/<page>/);
    my $data = '';
    do {
	$line = $fh->getline();
	$data .= $line;
    } while ($line !~ m/<(\/page|revision)>/);
    my $title = getField('title', $data);
    my $id = getField('id', $data);
    my $longid = sprintf("%012d", $id);
    my $outdir = OUTDIR . join("/", map { substr($longid, $_, 3) } (0,3,6,9) );
    mkpath($outdir, { verbose => 1, mode => 0750 });
    die "bad dir: $outdir" if !-d $outdir;
    open(OUT, ">$outdir/meta.txt") || die "open: $!";
    print OUT "$title\n";
    print OUT "$id\n";
    close(OUT);
    open(OUT, "| gzip --best > $outdir/revisions.txt.gz") || die "open: $!";
    if ($line =~ m/<revision>/) {
	while ($line !~ m#</page>#) {
	    print OUT $line;
	    $line = $fh->getline();
	}
    }
    close(OUT);
}

sub getField {
    my ($field, $data) = @_;
    if ($data =~ m#<$field>([^<]*)</$field>#) {
	return $1;
    }
    die "No field [$field] in [$data]";
}


#!/usr/bin/perl

use strict;
use warnings;
use open IN => ":utf8", OUT => ":utf8";
use URI::Escape;
use LWP::Simple;
use JSON::XS;
use Data::Dumper;
use DB_File;
use File::Path qw(mkpath);
use Encode;
use Carp;
use IO::Select;
use Storable qw(store_fd fd_retrieve);
use XML::Simple;
use Error qw(:try);

use constant WIKIAPI => 'http://en.wikipedia.org/w/api.php';
use constant USERAPI => 'http://toolserver.org/~Ipye/UserName2UserId.php';

my $outdir = shift @ARGV;
my $pageid = shift @ARGV;

my (%lastrevid, %userid, %pageid);

tieHashes();
my $file = getOutfile($pageid);
$lastrevid{$pageid} = 0;
unlink($file);
untieHashes();
exit(0);


sub tieHashes {
    tie %lastrevid, 'DB_File', 'lastrev.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
    tie %userid, 'DB_File', 'userid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
    tie %pageid, 'DB_File', 'pageid.db', O_RDWR|O_CREAT, 0644, $DB_BTREE;
}

sub untieHashes {
    untie %pageid;
    untie %userid;
    untie %lastrevid;
}

sub getOutfile {
    my $pageid = shift @_;
    my $longid = sprintf("%012d", $pageid);

    my $outdir = $outdir ."/". join("/", map { substr($longid, $_, 3) } (0,3,6) );
    mkpath($outdir, { verbose => 0, mode => 0750 });

    my $file = $outdir . "/" . $longid . ".gz";
    return $file;
}


#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use AI::Genetic;
use Data::Dumper;
use Error qw(:try);
use DBI;
use Time::HiRes qw(gettimeofday tv_interval);


my @population = (
#	[2,512,1024,64,1,8,1,1,0,2,1,0,0,64,3],
#	[1,3145,1600,874,1,0,0,2,0,0,2,1,0,64,3],
#	[1,3145,1600,874,1,0,0,2,0,1,3,0,1,64,3],
#	[1,3145,1600,874,1,0,0,1,0,2,4,1,1,64,3],
#	[1,3145,1600,874,1,0,0,2,0,1,8,0,0,64,3],
#	[1,3145,1600,874,1,0,0,0,2,1,8,1,0,64,3],
#	[1,3145,1600,874,1,0,0,0,1,2,8,0,1,64,3],
#        [1,3733,1874,456,2,6,1,2,0,1,4,1,1,64,3],
#        [1,3733,1874,456,2,4,1,2,0,1,4,0,0,64,3],
#        [1,3733,1874,106,2,4,1,2,0,1,4,1,0,64,3],
#        [1,3733,1874,456,2,6,1,2,2,1,4,0,1,64,3],
#        [1,3733,1874,106,2,4,1,2,2,1,4,1,1,64,3],
        [1,3906,1874,456,2,12,1,2,0,1,4,0,0,64,3],
        [1,3906,1874,456,2,16,1,2,0,1,4,1,0,64,3],
        [1,3733,1874,456,2,12,1,2,0,1,4,0,1,64,3],
	[1,3733,1874,106,2,58,1,2,0,2,4,0,0,38,3],		# 260
	[1,3733,1874,456,2,4,1,1,2,2,4,0,0,64,3],
	[1,3733,1874,106,2,58,1,2,0,1,4,0,1,38,3],
	[1,3733,1874,106,2,4,1,2,2,1,4,1,1,27,3],
	[1,3906,1874,456,2,21,1,2,0,1,4,0,0,64,3],
);

my $opt = {
	'population' => 20,
	'generations' => 15,
	'timing' => 0,
	'mutation' => 0.05,
	'dbname' => 'ptwikidb',
	'dbuser' => 'debian-sys-maint',
	'dbpass' => 'OSNZHR9DOKOf5lfT',
    };
GetOptions($opt, 'timing', 'dir=s', 'population=i', 'dbname=s', 'dbuser=s', 'dbpass=s');

die "Need directory of blobs" if !defined $opt->{dir};

if ($opt->{timing}) {
    foreach my $genes (@population) {
	my $fitness = test_mysql($genes);
	show_individual(@$genes);
	print "TIMING = ", 1/$fitness, "\n\n";
    }
} else {
    my $ga = AI::Genetic->new(
	    -population => $opt->{population},
	    -mutation => $opt->{mutation},
	    -fitness => \&test_mysql,
	    -type => 'rangevector',
	    -terminate => \&test_terminate,
	);

    $ga->init([
	    [0,2],
	    [256,4096],
	    [128,1000],
	    [2,1024],
	    [0,2],
	    [0,64],
	    [0,1],
	    [0,2],
	    [0,2],
	    [0,2],
	    [1,16],		# loadThreads
	    [0,1],		# notnull
	    [0,1],		# indexbefore
	    [0,64],		# fileThreads
	    [2,4],		# logfiles
	]);

    $ga->inject(scalar(@population), @population);

    $ga->evolve(rouletteTwoPoint => $opt->{generations});

    print "Final Winners\n";
    for my $i ($ga->getFittest(10)) {
	print "Score: ", $i->score, "\n";
	my @genes = $i->genes;
	print Dumper(\@genes), "\n";
	show_individual($i->genes);
    }
}

exit(0);

sub printChoice {
    my $field = shift @_;
    my $choice = shift @_;
    print STDERR "BAD FIELD[$field,$choice]\n" if !defined $choice || !defined $_[$choice];
    print "$field=$_[$choice]\n";
    return $_[$choice];
}

sub show_individual {
    my @genes = @_;
    print <<_END_;
[mysqld]
innodb_autoextend_increment=1000
innodb_data_file_path=ibdata1:10G
innodb_additional_mem_pool_size=256M
max_allowed_packet=64M
thread_cache_size=64
_END_
    my $flush = shift @genes;
    printChoice('innodb_flush_method', $flush-1, 'O_DIRECT', 'O_DSYNC' ) if $flush;
    print "innodb_buffer_pool_size=",shift @genes, "M\n";
    print "innodb_log_file_size=", shift @genes, "M\n";
    print "innodb_log_buffer_size=", shift @genes, "M\n";
    my $commit = shift @genes;
    printChoice("innodb_flush_log_at_trx_commit", $commit-1, '1', '2') if $commit;
    my $threads = shift @genes;
    printChoice("innodb_thread_concurrency", $threads-1, 1..64) if $threads;
    my $table = shift @genes;
    print "innodb_file_per_table\n" if $table;
    printChoice("innodb_log_group_home_dir", shift @genes, '/tmp/mysql-ga/logdir', '/big/mysql-ga/logdir', '/giant/mysql-ga/logdir');
    printChoice("tmpdir", shift @genes, '/tmp/mysql-ga/tmpdir', '/big/mysql-ga/tmpdir', '/giant/mysql-ga/tmpdir');
    my $datadir = printChoice("datadir", shift @genes, '/tmp/mysql-ga/datadir', '/big/mysql-ga/datadir', '/giant/mysql-ga/datadir');
    my $loadThreads = shift @genes;
    print "# loadThreads = $loadThreads\n";
    my $notnull = shift @genes;
    print "# notnull = $notnull\n";
    my $indexbefore = shift @genes;
    print "# indexbefore = $indexbefore\n";
    my $fileThreads = shift @genes;
    printChoice("innodb_file_io_threads", $fileThreads-1, 1..64) if $fileThreads;
    print "innodb_log_files_in_group=", shift @genes, "\n";
    return ($datadir, $loadThreads, $notnull, $indexbefore);
}

sub test_mysql {
    my $genes = shift @_;

    system("/etc/init.d/mysql stop");
    while(1) { my $ps = `ps -ef`; last if $ps !~ m/mysqld/; };

    # clean up dirs
    my @dirs = qw( /tmp/mysql-ga /big/mysql-ga /giant/mysql-ga );
    my @subdirs = qw( tmpdir logdir datadir );
    foreach my $d (@dirs) {
	foreach my $s (@subdirs) {
	    system("rm -rf $d/$s");
	    system("mkdir -p $d/$s");
	    system("chown -R mysql.mysql $d/$s");
	}
    }


    # write config
    open(OUT, ">/etc/mysql/conf.d/wikitrust.cnf") || die "open: $!";
    select(OUT);
    my ($datadir, $loadThreads, $notnull, $indexbefore) = show_individual(@$genes);
    select(STDOUT);
    close(OUT);

    # create new datadir
    system("rsync -a --delete /var/lib/mysql.bk2/ $datadir");
    # and remove old InnoDB files so that they are recreated
    system("rm -rf $datadir/ib*");

    # restart db
    system("/etc/init.d/mysql restart");
    my $t0 = [gettimeofday];
    while(1) { my $ps = `/etc/init.d/mysql status`; last if $ps !~ m/stopped/ || tv_interval($t0) > 300; };
    print "Loading database...\n";
    system("echo 'create database ".$opt->{dbname}.";' | mysql -u ".$opt->{dbuser}." -p".$opt->{dbpass}." mysql");
    system("/bin/sync");

    my $start = [gettimeofday];
    # run the test
if (0) {
    system("mysql -u debian-sys-maint -pOSNZHR9DOKOf5lfT ptwikidb < ptwikidb.dump");
} else {
    create_schema($notnull);
    create_index() if $indexbefore;
    system("./load_db.pl ". join(' ', (map { $opt->{$_} } qw(dbname dbuser dbpass)), $loadThreads, $opt->{dir}));
    create_index() if !$indexbefore;
}
    system("/bin/sync");
    my $ok = 0;
    try {
	my $dbh = DBI->connect('DBI:mysql:database='.$opt->{dbname}.':host=localhost', $opt->{dbuser}, $opt->{dbpass}, { RaiseError => 1, AutoCommit => 1 } );
	my $sth = $dbh->prepare('SELECT COUNT(*) from wikitrust_revision');
	$sth->execute();
	if ($sth->rows > 0) {
	    my @result = $sth->fetchrow_array();
#	    $ok = 1 if $result[0] == 11439893;
#	    print "Bad results:$result[0]\n" if $result[0] != 11439893;
#	    exit(0) if $result[0] != 11439893;
	    $ok = 1 if $result[0] == 11439887;
	    print "Bad results:$result[0]\n" if $result[0] != 11439887;
	}
	$sth->finish();
	$dbh->disconnect();
    } otherwise { print shift, "\n"; };

    my $diff = tv_interval($start);

    if ((!$ok) || ($diff < 20)) {
	$diff = 1E6;
	print "BAD CONFIG: ", Dumper($genes), "\n";
    }

    return 1.0/$diff;
}

sub test_terminate {
    my $ga = shift;
    print "FITTEST ===> ", $ga->getFittest->score, "\n";
    my @genes = $ga->getFittest->genes;
    print Dumper(\@genes), "\n";
    show_individual($ga->getFittest->genes);
    return 0;
}

sub create_schema {
    my $notnull = shift @_;

    $notnull = " NOT NULL " if $notnull;
    $notnull = "" if !$notnull;


my $createcmds = <<"_END_";
CREATE TABLE wikitrust_global (
       median                     float,
       rep_0                      float,
       rep_1                      float,
       rep_2                      float,
       rep_3                      float,
       rep_4                      float,
       rep_5                      float,
       rep_6                      float,
       rep_7                      float,
       rep_8                      float,
       rep_9                      float
) ENGINE=InnoDB;

INSERT INTO wikitrust_global VALUES (0,0,0,0,0,0,0,0,0,0,0);

CREATE TABLE wikitrust_page (
       page_id             int,
       page_title          varbinary(255) UNIQUE,
       page_info           text $notnull,
       last_blob           int DEFAULT 8
/* ,	PRIMARY KEY (page_id) */
) ENGINE=InnoDB;


CREATE TABLE wikitrust_vote (
       revision_id         int $notnull,
       page_id             int $notnull,   
       voter_name          varbinary(255) $notnull,
       voted_on            varchar(32) $notnull,
       processed           bool DEFAULT false,
       PRIMARY KEY (revision_id, voter_name)
) ENGINE=InnoDB;


CREATE TABLE wikitrust_revision (
        revision_id             int,
        page_id                 int,
        text_id                 int,
        time_string             binary(14),
        user_id                 int, 
        username                varchar(255), 
        is_minor                tinyint(3) unsigned, 
        quality_info            text $notnull, 
        blob_id                 int $notnull,
        reputation_delta        float DEFAULT 0.0,
        overall_trust           float DEFAULT 0.0,
        overall_quality         float
/* , PRIMAY KEY (revision_id) */
) ENGINE=InnoDB;


CREATE TABLE wikitrust_blob (
        blob_id                 decimal(24) PRIMARY KEY, 
        blob_content            longblob $notnull
) ENGINE=InnoDB;

CREATE TABLE wikitrust_user (
       user_id     serial PRIMARY KEY,
       username    varchar(255),
       user_rep    float DEFAULT 0.0
) ENGINE=InnoDB;


CREATE TABLE wikitrust_queue (
       page_id         int $notnull,
       page_title      varchar(255) PRIMARY KEY, 
       requested_on    timestamp DEFAULT now(),
       processed       ENUM('unprocessed', 'processing', 'processed') $notnull DEFAULT 'unprocessed',
       priority        int unsigned DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE wikitrust_text_cache (
       revision_id     int PRIMARY KEY,
       page_id         int,
       time_string     binary(14),
       revision_text   longtext $notnull
) ENGINE=InnoDB;

_END_

    open(OUT, "| mysql -u ".$opt->{dbuser}." -p".$opt->{dbpass}." ".$opt->{dbname}) || die "open: $!";
    print OUT $createcmds;
    close(OUT);
}


sub create_index {
return;
my $indexcmds = <<"_END_";
CREATE INDEX wikitrust_page_title_idx ON wikitrust_page (page_title);
CREATE INDEX wikitrust_voted_processed_idx ON wikitrust_vote (voted_on, processed);
CREATE INDEX wikitrust_revision_id_timestamp_idx ON wikitrust_revision (page_id, time_string, revision_id);
CREATE INDEX wikitrust_usernames_idx ON wikitrust_user (username);

CREATE INDEX wikitrust_queue_idx ON wikitrust_queue (processed, requested_on); 
CREATE INDEX wikitrust_text_cache ON wikitrust_text_cache (revision_id, time_string, page_id);
_END_

    open(OUT, "| mysql -u ".$opt->{dbuser}." -p".$opt->{dbpass}." ".$opt->{dbname}) || die "open: $!";
    print OUT $indexcmds;
    close(OUT);
}


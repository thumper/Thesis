#!/usr/bin/perl

use DB_File;

my %timing;
tie %timing, 'DB_File', "timing.db", O_RDONLY, 0666, $DB_HASH;

print join(',', qw(IOmode BufferPoolSz LogfileSz LogBufSz FlushAtCommit
		Threads FilePerTable LogGroupDir TmpDir DataDir
		LoadThreads NotNull IndexBefore FileIOThreads
		LogFilesInGroup Time)),
	"\n";

while (my ($key, $val) = each %timing) {
    $key =~ s/^[^;]+;//;
    print "$key,$val\n";
}
untie %timing;

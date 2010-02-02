#!/bin/sh

set -e
set -x

../extract-usergroups.pl 
../extract-entries.pl rankings.txt < uids-midline.txt > rankings-midline.txt
../extract-entries.pl rankings.txt < uids-thiehi.txt > rankings-thiehi.txt
../extract-entries.pl rankings.txt < uids-thielo.txt > rankings-thielo.txt
../extract-entries.pl rankings.txt < uids-tloelo.txt > rankings-tloelo.txt
../extract-entries.pl rankings.txt < uids-tloehi.txt > rankings-tloehi.txt


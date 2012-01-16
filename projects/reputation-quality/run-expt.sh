#!/bin/bash
set -e
set -x

. ./vars.sh

# Make sure that source code is on the correct branch
branch=$(cd $WIKITRUST; git symbolic-ref HEAD 2> /dev/null)
branch=${branch#refs/heads/}
if [ "$branch" != "thumper-vandalrep" ]; then
  echo "ERROR: On wrong source branch!"
  exit 1
fi

mkdir -p $WORKDIR
#(cd $WORKDIR ; rm -rf $OUTPUT)
(cd $WORKDIR ; mkdir -p $OUTPUT/cmds)
mkdir -p $WORKDIR/$OUTPUT/cmds
cp -a $WIKITRUST/analysis/*  $WORKDIR/$OUTPUT/cmds/
rm -f $WORKDIR/$OUTPUT/cmds/*.o
rm -f $WORKDIR/$OUTPUT/cmds/*.ml
rm -f $WORKDIR/$OUTPUT/cmds/*.cm*
rm -f $WORKDIR/$OUTPUT/cmds/*.annot
cp -ar ./pan2010.csv $WORKDIR/
cp -a $WIKITRUST/util/batch_process.py  $WORKDIR/$OUTPUT/cmds/


# splitwiki step - must run on single host
(ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WORKDIR ; \
  time nice python $OUTPUT/cmds/batch_process.py \
  --n_core $CORES --nice --cmd_dir $OUTPUT/cmds --dir $OUTPUT \
  --do_split $ENDUMP)

exit 0

# compute stats - can be parallelized

(ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WORKDIR ; \
  time nice python $OUTPUT/cmds/batch_process.py \
  --n_core $CORES --nice --cmd_dir $OUTPUT/cmds --dir $OUTPUT \
  --do_compute_stats $ENDUMP)

# sort stats - must run on single host

(ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WORKDIR ; \
  time nice python $OUTPUT/cmds/batch_process.py \
  --n_core $CORES --nice --cmd_dir $OUTPUT/cmds --dir $OUTPUT
  --do_sort_stats $ENDUMP)

# compute rep - must run on single host

(ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WORKDIR ; \
  time nice python $OUTPUT/cmds/batch_process.py \
  --n_core $CORES --nice --cmd_dir $OUTPUT/cmds --dir $OUTPUT \
  --do_compute_rep --do_compute_trust $ENDUMP)

# compute trust - can be parallelized

(ulimit -v $MAXMEM -m $MAXMEM -d $MAXMEM; cd $WORKDIR ; \
  time nice python $OUTPUT/cmds/batch_process.py \
  --n_core $CORES --nice --cmd_dir $OUTPUT/cmds --dir $OUTPUT \
  --do_compute_trust $ENDUMP)


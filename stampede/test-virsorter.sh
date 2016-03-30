#!/bin/bash

#SBATCH -J VirSorter
#SBATCH -N 1
#SBATCH -n 16
#SBATCH -p normal
#SBATCH -o VirSorter-%j.out
#SBATCH -t 48:00:00

BIN="$( readlink -f -- "$( dirname -- "$0" )" )"
WDIR=$WORK/stampede-virsorter/stampede
PARAM="$WDIR/paramlist"
LOG="$WDIR/launcher.log"
SOURCE_DIR=$WORK/delong/fasta 
VIRSORTER="$WDIR/VirSorter/wrapper_phage_contigs_sorter_iPlant.pl"
VIRSORTER_DB_DIR="$WORK/virsorter-data"

module load launcher/2.0
module load blast 
module load intel/13.0.2.146
module load mvapich2/1.9a2
module load hmmer/3.0
module load muscle/3.8.31

function lc() {
  wc -l $1 | cut -d ' ' -f 1
}

echo "Starting VirSorter" > $LOG

if [[ -e $PARAM ]]; then
  echo "Removing old param file \"$PARAM\"" >> $LOG
  rm -f $PARAM
fi

if [[ -e bin.tgz ]]; then
  echo "Untarring bin.tgz" >> $LOG
  tar -xvf bin.tgz
  export PATH=$PATH:"$BIN/bin"
else
  echo "Cannot find bin.tgz" >> $LOG
fi

FILES_LIST=$(mktemp)
find $SOURCE_DIR -type f > $FILES_LIST
NUM_FILES=$(lc $FILES_LIST)

echo "Found \"$NUM_FILES\" files in \"$SOURCE_DIR\"" >> $LOG

if [[ $NUM_FILES -lt 1 ]]; then
  echo "Nothing to do" >> $LOG
  exit 1
fi

cat -n $FILES_LIST >> $LOG

i=0
while read FILE; do
  let i++

  BASENAME=$(basename $FILE)
  OUT_DIR=$WORK/delong/${BASENAME%.fasta}
  echo "time $VIRSORTER -f $FILE --db 1 --wdir $OUT_DIR --data-dir $VIRSORTER_DB_DIR" >> $PARAM
done < $FILES_LIST

export TACC_LAUNCHER_NPHI=0
export TACC_LAUNCHER_PPN=2
export EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
export WORKDIR=$BIN
export TACC_LAUNCHER_SCHED=interleaved

echo "Starting parallel job..." >> $LOG
echo $(date) >> $LOG

time $TACC_LAUNCHER_DIR/paramrun SLURM $EXECUTABLE $WORKDIR $PARAM

echo $(date) >> $LOG
echo "Done" >> $LOG

# Now, delete the bin/ directory
#rm -rf bin

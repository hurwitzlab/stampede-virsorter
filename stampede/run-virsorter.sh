#!/bin/bash

set -u

BIN="$( readlink -f -- "$( dirname -- "$0" )" )"
# WDIR=$WORK/virsorter-1.0.4/stampede
PARAM="./paramlist"
LOG="./launcher.log"
VIRSORTER="./VirSorter/wrapper_phage_contigs_sorter_iPlant.pl"
PARTITION=${PARTITION:-"normal"}
OUT_DIR=${OUT_DIR:-"virsorter-out"}
IN_DIR=${IN_DIR:-""}
VIRSORTER_DB_DIR=${DB_DIR:-"$WORK/virsorter-data"}
DB_CHOICE=${DB_CHOICE:-"RefSeqDB"}
OPT_SEQ=${OPT_SEQ:-""}

function HELP() {
  printf "Usage:\n  %s -i IN_DIR -o OUT_DIR\n\n" \ $(basename $0)

  echo "Required arguments:"
  echo " -i INPUT_DIR"
  echo ""
  echo "Options (default in parentheses):"
  echo " -o OUT_DIR ($OUT_DIR)"
  echo " -d DB_DIR ($VIRSORTER_DB_DIR)"
  echo " -p PARTITION ($PARTITION)"
  echo " -c DB_CHOICE ($DB_CHOICE)"
  echo " -a CUSTOM_PHAGE_SEQUENCE"
  echo ""
  exit 0
}

while getopts :a:c:d:i:p:o:h OPT; do
  case $OPT in
    a)
      OPT_SEQ="$OPTARG"
      ;;
    c)
      DB_CHOICE="$OPTARG"
      ;;
    d)
      VIRSORTER_DB_DIR="$OPTARG"
      ;;
    i)
      IN_DIR="$OPTARG"
      ;;
    h)
      HELP
      ;;
    o)
      OUT_DIR="$OPTARG"
      ;;
    p)
      PARTITION="$OPTARG"
      ;;
    :)
      echo "Error: Option -$OPTARG requires an argument."
      exit 1
      ;;
    \?)
      echo "Error: Invalid option: -${OPTARG:-""}"
      exit 1
  esac
done

if [[ -e $LOG ]]; then
  rm -f $LOG
fi

if [[ ${#IN_DIR} -lt 1 ]]; then
  echo "IN_DIR not defined." >> $LOG
  exit 1
fi

if [[ ! -d $IN_DIR ]]; then
  echo "IN_DIR \"$IN_DIR\" does not exist." >> $LOG
  exit 1
fi

if [[ ! -d $OUT_DIR ]]; then
  mkdir -p $OUT_DIR
fi

if [[ $DB_CHOICE -lt 1 ]] || [[ $DB_CHOICE -gt 2 ]]; then
  echo "DB_CHOICE \"$DB_CHOICE\" must be 1 or 2." >> $LOG
  exit 1
fi

module load launcher/2.0
module load blast 
module load intel/13.0.2.146
module load mvapich2/1.9a2
module load hmmer/3.0
module load muscle/3.8.31

function lc() {
  wc -l $1 | cut -d ' ' -f 1
}

echo "Starting VirSorter $(date)"  > $LOG
echo "IN_DIR   \"$IN_DIR\""       >> $LOG
echo "OUT_DIR  \"$OUT_DIR\""      >> $LOG

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
CUSTOM_PHAGE_ARG=""
if [[ -n $OPT_SEQ ]]; then
  CUSTOM_PHAGE_ARG="--cp $OPT_SEQ"
fi
i=0
while read FILE; do
  let i++

  BASENAME=$(basename $FILE)
  OUT=$OUT_DIR/${BASENAME%.fasta}

  echo "$VIRSORTER -f $FILE --db $DB_CHOICE --wdir $OUT --data-dir $VIRSORTER_DB_DIR $CUSTOM_PHAGE_ARG" >> $PARAM
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
echo "Done"  >> $LOG

# Now, delete the bin/ directory
#rm -rf bin

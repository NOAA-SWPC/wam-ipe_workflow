#!/bin/ksh
set -x

CDATE=${1:-""}
CDUMP=${2:-""}
SOURCE_DIR=${3:-$COMINgfs}
TARGET_DIR=${4:-$COMOUT}

DUMP_SUFFIX=${DUMP_SUFFIX:-""}

# Exit if SORUCE_DIR does not exist
if [ ! -s $SOURCE_DIR ]; then
   echo "***ERROR*** DUMP SOURCE_DIR=$SOURCE_DIR does not exist"
   exit 99
fi


# Create TARGET_DIR if is does not exist
if [ ! -s $TARGET_DIR ]; then mkdir -p $TARGET_DIR ;fi

# Set file prefix
cyc=`echo $CDATE |cut -c 9-10`
prefix="$CDUMP.t${cyc}z."

# Link dump files from SOURCE_DIR to TARGET_DIR
cd $SOURCE_DIR
for file in ${prefix}*seaice.5min* ${prefix}*snogrb* \
            ${prefix}*syndata.tcvitals*; do
    [ ! -f $file ] && export err=1 && err_exit "required global dump data unavailable"
    if [ $RUN_ENVIR = 'nco' ] ; then
        cp --preserve=mode,ownership $SOURCE_DIR/$file $TARGET_DIR/w${file:1}
    else
        ln -fs $SOURCE_DIR/$file $TARGET_DIR/w${file:1}
    fi
done
exit 0




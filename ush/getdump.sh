#!/bin/ksh
set -x

CDATE=${1:-""}
CDUMP=${2:-""}
SOURCE_DIR=${3:-$COMINobsproc}
TARGET_DIR=${4:-$COMOUT}

DUMP_SUFFIX=${DUMP_SUFFIX:-""}

# Exit if SORUCE_DIR does not exist
if [ ! -s $SOURCE_DIR ]; then
   echo "***FATAL ERROR*** DUMP SOURCE_DIR=$SOURCE_DIR does not exist"
   exit 99
fi


# Create TARGET_DIR if is does not exist
if [ ! -s $TARGET_DIR ]; then mkdir -p $TARGET_DIR ;fi


# Set file prefix
cyc=`echo $CDATE |cut -c 9-10`
prefix="$CDUMP.t${cyc}z."

# Link dump files from SOURCE_DIR to TARGET_DIR
cd $SOURCE_DIR
if [ -s ${prefix}updated.status.tm00.bufr_d ]; then
    for file in ${prefix}*bufr_d ${prefix}*engicegrb ${prefix}*dump_alert_flag* ${prefix}*rtgssthr* \
                ${prefix}*seaice.5min* ${prefix}*imssnow96* ${prefix}*prepbufr*; do
        [ ! -f $file ] && export err=1 && err_exit "FATAL ERROR: required prep dump data unavailable"
        if [ $RUN_ENVIR = 'nco' ] ; then
            cp --preserve=mode,ownership $SOURCE_DIR/$file $TARGET_DIR/w${file:1}
        else
            ln -fs $SOURCE_DIR/$file $TARGET_DIR/w${file:1}
        fi
    done
else
    echo "***FATAL ERROR*** ${prefix}updated.status.tm00.bufr_d NOT FOUND in $SOURCE_DIR"
    exit 99
fi

exit 0




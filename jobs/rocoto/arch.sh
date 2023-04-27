#!/bin/ksh -x
if [ ! -z ${PBS_O_WORKDIR} ]; then cd $PBS_O_WORKDIR; fi
###############################################################
## Abstract:
## Archive driver script
## RUN_ENVIR : runtime environment (emc | nco)
## HOMEwfs   : /full/path/to/workflow
## EXPDIR : /full/path/to/config/files
## CDATE  : current analysis date (YYYYMMDDHH)
## CDUMP  : cycle name (wdas / wfs / wrs)
## PDY    : current date (YYYYMMDD)
## cyc    : current cycle (HH)
###############################################################

###############################################################
# Source wamipe workflow modules
. $HOMEwfs/ush/load_wamipe_modules.sh
status=$?
[[ $status -ne 0 ]] && exit $status

###############################################################
# Source relevant configs
configs="base arch"
for config in $configs; do
    . $EXPDIR/config.${config}
    status=$?
    [[ $status -ne 0 ]] && exit $status
done

# ICS are restarts and always lag INC by $assim_freq hours
ARCHINC_CYC=$ARCH_CYC
ARCHICS_CYC=$((ARCH_CYC-assim_freq))
if [ $ARCHICS_CYC -lt 0 ]; then
    ARCHICS_CYC=$((ARCHICS_CYC+24))
fi

# CURRENT CYCLE
APREFIX="${CDUMP}.t${cyc}z."
ASUFFIX=""

# Realtime parallels run GFS MOS on 1 day delay
# If realtime parallel, back up CDATE_MOS one day
CDATE_MOS=$CDATE
if [ $REALTIME = "YES" ]; then
    CDATE_MOS=$($NDATE -24 $CDATE)
fi
PDY_MOS=$(echo $CDATE_MOS | cut -c1-8)

###############################################################
# Archive online for verification and diagnostics
###############################################################

export COMIN=${COMIN:-$(compath.py $NET/${wfs_ver}/$CDUMP.$PDY/$cyc)}
export COMOUT=${COMOUT:-$(compath.py -o $NET/${wfs_ver}/$CDUMP.$PDY/$cyc)}

mkdir -p $COMOUT
cd $COMOUT

if [ $COMIN != $COMOUT ] ; then
    ln -fs $COMIN/* .
fi

###############################################################
# Archive data to HPSS
if [ $HPSSARCH = "YES" ]; then
###############################################################

#--determine when to save ICs for warm start and forecat-only runs
SAVEWARMICA="NO"
SAVEWARMICB="NO"
SAVEFCSTIC="NO"
firstday=$($NDATE +24 $SDATE)
mm=`echo $CDATE|cut -c 5-6`
dd=`echo $CDATE|cut -c 7-8`
nday=$(( (mm-1)*30+dd ))
mod=$(($nday % $ARCH_WARMICFREQ))

ARCH_LIST="$COMOUT/archlist"
[[ -d $ARCH_LIST ]] && rm -rf $ARCH_LIST
mkdir -p $ARCH_LIST
cd $ARCH_LIST

$HOMEwfs/ush/hpssarch_gen.sh $CDUMP
status=$?
if [ $status -ne 0  ]; then
    echo "$HOMEwfs/ush/hpssarch_gen.sh $CDUMP failed, ABORT!"
    exit $status
fi

cd $COMOUT/../..

export ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
htar -P -hcvf $ATARDIR/$CDATE/${CDUMP}.tar $(cat $ARCH_LIST/${CDUMP}.txt)
export ERR=$?
export err=$ERR
$ERRSCRIPT||exit 2

###############################################################
fi  ##end of HPSS archive
###############################################################



###############################################################
# Clean up previous cycles; various depths
# PRIOR CYCLE: Leave the prior cycle alone
GDATE=$($NDATE -$assim_freq $CDATE)

# PREVIOUS to the PRIOR CYCLE
GDATE=$($NDATE -$assim_freq $GDATE)
gPDY=$(echo $GDATE | cut -c1-8)
gcyc=$(echo $GDATE | cut -c9-10)

# Remove the TMPDIR directory
COMIN="$RUNDIR/$GDATE"
[[ -d $COMIN ]] && rm -rf $COMIN

if [[ "${DELETE_COM_IN_ARCHIVE_JOB:-YES}" == NO ]] ; then
    exit 0
fi

# Step back every assim_freq hours
# and remove old rotating directories for successful cycles
# defaults from 24h to 120h
GDATEEND=$($NDATE -${RMOLDEND:-24}  $CDATE)
GDATE=$(   $NDATE -${RMOLDSTD:-120} $CDATE)
while [ $GDATE -le $GDATEEND ]; do
    gPDY=$(echo $GDATE | cut -c1-8)
    gcyc=$(echo $GDATE | cut -c9-10)
    COMOUT=$(compath.py -o $NET/${wfs_ver}/$CDUMP.$gPDY/$gcyc)
    if [ -d $COMOUT ]; then
        rocotolog="$EXPDIR/logs/${GDATE}.log"
	if [ -f $rocotolog ]; then
            testend=$(tail -n 1 $rocotolog | grep "This cycle is complete: Success")
            rc=$?
            [[ $rc -eq 0 ]] && rm -rf $COMOUT
	fi
    fi

    # Remove any empty directories
    COMOUT=$(compath.py -o $NET/${wfs_ver}/$CDUMP.$gPDY)
    if [ -d $COMOUT ]; then
        [[ ! "$(ls -A $COMIN)" ]] && rm -rf $COMOUT
    fi

    GDATE=$($NDATE +$assim_freq $GDATE)
done

###############################################################
exit 0

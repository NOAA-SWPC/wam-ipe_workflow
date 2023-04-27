#!/bin/bash
set -ax
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exwamipe_nowcast_service.sh
# Script description:  updates SWx driver file with incoming realtime obs
#
# Author: Adam Kubaryk      Org: NCEP/SWPC     Date: 2023-04-27
#
# Abstract: This script calls a Python wrapper around the SWx driver file
#           generation script, checking for incoming obs to update the nowcast
#           in realtime.
#
# $Id$
#
# Attributes:
#   Language: bash shell
#   Machine: WCOSS2/Hera
#
################################################################################

# path/variable setup
SIGI=${SIGI:-$COMIN/$CDUMP.t${cyc}z.$ATM$SUFOUT}

CDATE=$(eval $SIGHDR $SIGI idate)
FDATE=$($NDATE `eval $SIGHDR $SIGI fhour | cut -d'.' -f 1` $CDATE)

SWIO_IDATE=${FDATE}$(printf %02d $data_poll_interval_min)
SWIO_EDATE=$($NDATE $FHMAX $FDATE)00

# link lock files
sdate=$SWIO_IDATE
edate=$SWIO_EDATE
while [ $sdate -le $edate ] ; do
    $NLN $COMOUT/${CDUMP}.t${cyc}z.${sdate:0:8}_${sdate:8}00.lock ${sdate:0:8}_${sdate:8}00.lock
    sdate=$($MDATE $data_poll_interval_min $sdate)
done

# link actual target files in
${NLN} $COMOUT/$CDUMP.t${cyc}z.input_parameters.nc input_parameters.nc
${NLN} $COMOUT/$CDUMP.t${cyc}z.input_parameters.txt wam_input_f107_kp.txt

# wait if necessary
while [ ! -f input_parameters.nc ] ; do
    sleep 60
done

# and then pull and write drivers as they come in
$HOMEwfs/ush/realtime_wrapper.py -e $SWIO_EDATE -p $DCOM -d $data_poll_interval_min -c $($MDATE -$((36*60)) ${FDATE}00)

exit $?

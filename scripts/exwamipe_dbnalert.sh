#!/bin/bash
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exwamipe_dbnalert.sh
# Script description:  Produces DBN alerts
#
# Author: Xiaoxue Wang      Org: NCEP/IDSB     Date: 2023-0509
#
# Abstract: This script issues DBNet alerts.
#
# Attributes:
#   Language: bash shell
#   Machine: WCOSS2
#
################################################################################

set -x

#cd $COMIN

if [  ! -s $COMIN/alert.done.t${cyc}z ]; then
  if [ $CDUMP = "wfs" ]; then
    FHSTART=$($NDATE -3 $PDY$cyc)
    icnt=0
    while [ $icnt -lt 60 ]
    do
      if [ -s $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc ];then
        sleep 15
        $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc
        break
      else
       sleep 10
       icnt=$((icnt + 1)) 
      fi
      if [ $icnt -ge 54 ]; then
        msg="FATAL: ABORTING after 20 minutes of waiting for $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc"
        err_exit $msg
      fi
    done  
  elif [ $CDUMP = "wrs" ]; then
    FHSTART=$($NDATE 3 $PDY$cyc)
  fi
  YMDSTART=`echo $FHSTART |cut -c1-8`
  HHSTART=`echo $FHSTART |cut -c9-10`
  MMSTART=05
else
  if [ $CDUMP = "wrs" -a ${ALERT_INPUT_ONLY:-NO} = "YES" ]; then
    $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc
    exit
  fi
  YMDSTART=`cat $COMIN/alert.done.t${cyc}z | awk -F"_" '{print $1}'`
  HHSTART=`cat $COMIN/alert.done.t${cyc}z | awk -F"_" '{print $2}' |cut -c1-2`
  MMSTART=`cat $COMIN/alert.done.t${cyc}z | awk -F"_" '{print $2}' |cut -c3-4`
  FHSTART=`echo $YMDSTART$HHSTART`
fi

if [ $CDUMP = wfs ]; then
  FHEND=$($NDATE 48 $PDY$cyc)
elif [ $CDUMP = "wrs" ]; then
  FHEND=$($NDATE 11 $PDY$cyc)
fi
YMDEND=`echo $FHEND |cut -c1-8`
HHEND=`echo $FHEND |cut -c9-10`

SSstart=`date -d "$YMDSTART $HHSTART" +%s`
SSend=`date -d "$YMDEND $HHEND" +%s`
MMstart=$((SSstart + 60 * $MMSTART))
TH=$MMstart

FS_WAM05=67268
FS_WAM10=39314260
FS_IPE05=100464
FS_IPE10=22804476
while [ $TH -le $SSend ]
do
  THD=`date -d @$TH +%Y%m%d%H%M%S`
  YMD=`echo $THD |cut -c1-8`
  HH=`echo $THD |cut -c9-10`
  MM=`echo $THD |cut -c11-12`
  ML=`echo $MM |cut -c2`
  if [ $ML -eq 5 ]; then
    type="wam05 ipe05"
  else
    type="wam05 wam10 ipe05 ipe10"
  fi

  for tp in $type 
  do
    file=$CDUMP.t${cyc}z.$tp.${YMD}_${HH}${MM}00.nc
    if [ $tp = wam05 ]; then
      FS=${FS_WAM05}
    elif [ $tp = wam10 ]; then
      FS=${FS_WAM10}
    elif [ $tp = ipe05 ]; then
      FS=${FS_IPE05}
    else
      FS=${FS_IPE10}
    fi  
    icnt=0
    while [ $icnt -lt 3300 ]
    do
      if [ -s $COMIN/$file ]; then
        filesize=`ls -l $COMIN/$file |awk '{print $5}'`
        if [ $filesize -eq $FS ] ;then
          $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job $COMIN/$file
          break
        else
          sleep 10
          icnt=$((icnt + 1))
        fi
      else
        sleep 10
        icnt=$((icnt + 1)) 
      fi
      if [ $icnt -eq 720 -o $icnt -eq 1440 -o $icnt -eq 2160 -o $icnt -eq 2880 ]; then
        nh=`expr $icnt / 360`
        echo "*********************************************************************************************" > mailmsg
        echo "***** WARNING: $COMIN/$file" >> mailmsg
        echo "***** is missing after $nh hours of waiting, we may have an outage for  " >> mailmsg
        echo "***** ${DCOMROOT}/${PDY}/swpc/geospace_input-${PDY}*.xml" >> mailmsg
        echo "**********************************************************************************************" >> mailmsg
        cat mailmsg |mail.py -s "WFS file missing after $nh hours" $MAILTO -v
      fi
    done # while icnt loop
  done # type loop
  echo ${YMD}_${HH}${MM}00 > $COMOUT/alert.done.t${cyc}z 
  TH=$((TH + 300)) 
done    

if [ $CDUMP = "wrs" ]; then
  icnt=0
  while [ $icnt -lt 60 ]
  do
    if [ -s $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc ];then
      sleep 15
      $DBNROOT/bin/dbn_alert MODEL ${DBN_ALERT_TYPE} $job $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc
      break
    else
     sleep 10
    fi
    if [ $icnt -ge 54 ]; then
      msg="FATAL: ABORTING after 20 minutes of waiting for $COMIN/${CDUMP}.t${cyc}z.input_parameters.nc"
      err_exit $msg
    fi
  done
fi

#!/bin/bash
set -x

###################################################
# Fanglin Yang, 20180318
# --create bunches of files to be archived to HPSS
###################################################

type=${1:-wfs}                ##wfs, wdas

CDATE=${CDATE:-2018010100}
PDY=$(echo $CDATE | cut -c 1-8)
cyc=$(echo $CDATE | cut -c 9-10)

#-----------------------------------------------------
if [ $type = "wfs" ]; then
#-----------------------------------------------------
  FHMIN_WFS=${FHMIN_WFS:-0}
  FHMAX_WFS=${FHMAX_WFS:-48}
  FHOUT_WFS=${FHOUT_WFS:-3}
  FHMAX_HF_WFS=${FHMAX_HF_WFS:-0}
  FHOUT_HF_WFS=${FHOUT_HF_WFS:-1}


  rm -f wfs.txt
  touch wfs.txt

  dirpath="wfs.${PDY}/${cyc}/"
  dirname="./${dirpath}"

  head="wfs.t${cyc}z."

  #..................
  for fstep in prep anal fcst ; do
   if [ -s $ROTDIR/logs/${CDATE}/wfs${fstep}.log ]; then
     echo  "./logs/${CDATE}/wfs${fstep}.log         " >>wfs.txt
   fi
  done

  fh=0


  #..................
  echo  "${dirname}${head}???anl              " >>wfs.txt
  echo  "${dirname}${head}sfca03              " >>wfs.txt
  echo  "${dirname}${head}atmf00              " >>wfs.txt
  echo  "${dirname}${head}sfcf00              " >>wfs.txt
  echo  "${dirname}${head}?????.*.nc          " >>wfs.txt
  echo  "${dirname}${head}input_parameters.nc " >>wfs.txt
  echo  "${dirname}${head}abias*              " >>wfs.txt
#-----------------------------------------------------
fi   ##end of wfs
#-----------------------------------------------------

if [ $type = "wrs" ]; then

  FHMIN_WRS=${FHMIN_WRS:-0}
  FHMAX_WRS=${FHMAX_WRS:-9}
  FHOUT_WRS=${FHOUT_WRS:-3}
  FHMAX_HF_WRS=${FHMAX_HF_WRS:-0}
  FHOUT_HF_WRS=${FHOUT_HF_WRS:-1}


  rm -f wrs.txt
  touch wrs.txt

  dirpath="wrs.${PDY}/${cyc}/"
  dirname="./${dirpath}"

  head="wrs.t${cyc}z."

  #..................
  for fstep in prep anal fcst ; do
   if [ -s $ROTDIR/logs/${CDATE}/wrs${fstep}.log ]; then
     echo  "./logs/${CDATE}/wrs${fstep}.log         " >>wrs.txt
   fi
  done

  fh=0

  #..................
  echo  "${dirname}${head}?????.*.nc          " >>wrs.txt
  echo  "${dirname}${head}input_parameters.nc " >>wrs.txt
#-----------------------------------------------------
fi   ##end of wrs
#-----------------------------------------------------


#-----------------------------------------------------
if [ $type = "wdas" ]; then
#-----------------------------------------------------

  rm -f wdas.txt
  touch wdas.txt

  dirpath="wdas.${PDY}/${cyc}/"
  dirname="./${dirpath}"
  head="wdas.t${cyc}z."

  #..................
  echo  "${dirname}${head}atmanl              " >>wdas.txt
  echo  "${dirname}${head}sfca03              " >>wdas.txt
  echo  "${dirname}${head}IPE*                " >>wdas.txt
[[ $cyc == "00" ]] || [[ $cyc == "12" ]] &&  echo  "${dirname}${head}radstat" >>wdas.txt
  echo  "${dirname}${head}abias*              " >>wdas.txt
  for fstep in prep anal fcst ; do
   if [ -s $ROTDIR/logs/${CDATE}/wdas${fstep}.log ]; then
     echo  "./logs/${CDATE}/wdas${fstep}.log         " >>wdas.txt
   fi
  done

  fh=0
  while [ $fh -le 6 ]; do
    fhr=$(printf %02i $fh)
    echo  "${dirname}${head}atmf${fhr}          " >>wdas.txt
    echo  "${dirname}${head}sfcf${fhr}          " >>wdas.txt
    fh=$((fh+3))
  done
  echo  "${dirname}${head}input_parameters.nc " >>wdas.txt

#-----------------------------------------------------
fi   ##end of wdas
#-----------------------------------------------------


exit 0


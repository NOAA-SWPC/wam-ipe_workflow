#!/bin/bash
set -ex

#--make symbolic links for EMC installation and hardcopies for NCO delivery

RUN_ENVIR=${1}
machine=${2}

if [ $# -lt 2 ]; then
    echo '***ERROR*** must specify two arguements: (1) RUN_ENVIR, (2) machine'
    echo ' Syntax: link_gsmwam_ipe.sh ( nco | emc ) ( wcoss2 | hera )'
    exit 1
fi

if [ $RUN_ENVIR != emc -a $RUN_ENVIR != nco ]; then
    echo 'Syntax: link_gsmwam_ipe.sh ( nco | emc ) ( wcoss2 | hera )'
    exit 1
fi
if [ $machine != hera -a $machine != wcoss2 ]; then
    echo 'Syntax: link_gsmwam_ipe.sh ( nco | emc ) ( wcoss2 | hera )'
    exit 1
fi

LINK="ln -fs"
[[ $RUN_ENVIR = nco ]] && LINK="cp -rp"

pwd=$(pwd -P)

#------------------------------
#--model fix fields
#------------------------------
if [ $machine = "hera" ]; then
    FIX_DIR="/scratch1/NCEPDEV/swpc/WAM-IPE_DATA/WAM_FIX"
elif [ $machine = "wcoss2" ]; then
    FIX_DIR="/lfs/h1/swpc/wam/noscrub/swpc.wam/WAM_FIX"
fi
mkdir -p ${pwd}/../fix
cd ${pwd}/../fix                ||exit 8
for dir in GSM IPE_FIX MED_SPACEWX WAM_gh_L150 ; do
    [[ -d $dir ]] && rm -rf $dir
done
$LINK $FIX_DIR/* .

#---------------------------------------
#--add files from external repositories
#---------------------------------------
cd ${pwd}/../ush                ||exit 8
    for file in global_cycle_driver.sh global_cycle.sh ;  do
        $LINK ../sorc/wamipe_utils.fd/ush/$file                  .
    done

    for file in parse_realtime.py sw_from_f107_kp.py realtime_wrapper.py ; do
        $LINK ../sorc/gsmwam_ipe.fd/scripts/interpolate_input_parameters/$file .
    done

#------------------------------
#--add GSI file
#------------------------------
cd ${pwd}/../jobs               ||exit 8
    $LINK ../sorc/gsi.fd/jobs/JWAMIPE_ANALYSIS           .
#    $LINK ../sorc/obsproc_wamipe.fd/jobs/JWAMIPE_PREP    .
cd ${pwd}/../scripts            ||exit 8
    $LINK ../sorc/gsi.fd/scripts/exwamipe_analysis.sh    .
cd ${pwd}/../fix                ||exit 8
    [[ -d fix_gsi ]] && rm -rf fix_gsi
    $LINK ../sorc/gsi.fd/fix  fix_gsi


#------------------------------
#--link executables
#------------------------------

cd $pwd/../exec
executable=global_gsmwam_ipe.x
[[ -s $executable ]] && rm -f $executable
$LINK ../sorc/gsmwam_ipe.fd/NEMS/exe/NEMS.x $executable

for wamipe_utilsexe in \
     nemsio_get        chgsigfhr       chgsfcfhr     \
     global_sighdr     global_cycle    global_sfchdr ; do
    [[ -s $wamipe_utilsexe ]] && rm -f $wamipe_utilsexe
    $LINK ../sorc/wamipe_utils.fd/exec/$wamipe_utilsexe .
done

[[ -s global_gsi.x ]] && rm -f global_gsi.x

$LINK ../sorc/gsi.fd/exec/gsi.x global_gsi.x

#------------------------------


exit 0


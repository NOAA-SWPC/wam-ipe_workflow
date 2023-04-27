#!/bin/sh
set +x
#------------------------------------
# Exception handling is now included.
#------------------------------------

build_target=${1:-"all"}

if [ $build_target = "install" ] ; then

. ./link_gsmwam_ipe.sh nco wcoss2
exit $?

fi

export USE_PREINST_LIBS="true"
source ../versions/build.ver

build_dir=`pwd`
logs_dir=$build_dir/logs
if [ ! -d $logs_dir  ]; then
  echo "Creating logs folder"
  mkdir $logs_dir
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  echo "Creating ../exec folder"
  mkdir ../exec
fi

#------------------------------------
# GET MACHINE
#------------------------------------
[ $build_target = "all" ] && module reset && source ./machine-setup.sh > /dev/null 2>&1

#------------------------------------
# Exception Handling Init
#------------------------------------
ERRSCRIPT=${ERRSCRIPT:-'eval [[ $err = 0 ]]'}
err=0

#------------------------------------
# build COMIO
#------------------------------------
echo " .... Executing ./build_comio.sh $build_target .... "
./build_comio.sh $build_target > $logs_dir/build_comio_$build_target.log 2>&1
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "Fatal error in build_comio.sh"
    echo "The log file is in $logs_dir/build_comio_$build_target.log"
fi
((err+=$rc))

#------------------------------------
# build GSMWAM-IPE
#------------------------------------
echo " .... Executing ./build_gsmwam_ipe.sh $build_target .... "
./build_gsmwam_ipe.sh $build_target > $logs_dir/build_gsmwam_ipe_$build_target.log 2>&1
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "Fatal error in build_gsmwam_ipe.sh"
    echo "The log file is in $logs_dir/build_gsmwam_ipe_$build_target.log"
fi
((err+=$rc))

#------------------------------------
# build gsi
#------------------------------------
echo " .... Executing ./build_gsi.sh $build_target .... "
./build_gsi.sh $build_target > $logs_dir/build_gsi_$build_target.log 2>&1
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "Fatal error in build_gsi.sh"
    echo "The log file is in $logs_dir/build_gsi_$build_target.log"
fi
((err+=$rc))

#------------------------------------
# build wam-ipe_utils
#------------------------------------
echo " .... Executing ./build_wamipe_utils.sh $build_target .... "
./build_wamipe_utils.sh $build_target > $logs_dir/build_wamipe_utils_$build_target.log 2>&1
rc=$?
if [[ $rc -ne 0 ]] ; then
    echo "Fatal error in build_wamipe_utils.sh"
    echo "The log file is in $logs_dir/build_wamipe_utils_$build_target.log"
fi
((err+=$rc))

#------------------------------------
# build obsproc
#------------------------------------
#echo " .... Building obsproc .... "
#./build_obsproc.sh $build_target > $logs_dir/build_obsproc_$build_target.log 2>&1
#rc=$?
#if [[ $rc -ne 0 ]] ; then
#    echo "Fatal error in build_obsproc.sh"
#    echo "The log file is in $logs_dir/build_obsproc_$build_target.log"
#fi
#((err+=$rc))

# do additional cleanup
if [ $build_target = "clean" ] ; then

rm -f  ../exec/*
rm -rf ../fix/*
rm -f ../jobs/JWAMIPE_ANALYSIS
rm -f ../scripts/exwamipe_analysis.sh
rm -f ../ush/global_cycle*sh
for file in parse_realtime.py sw_from_f107_kp.py realtime_wrapper.py ; do
    rm -f ../ush/$file
done

fi

#------------------------------------
# Exception Handling
#------------------------------------
[[ $err -ne 0 ]] && echo "FATAL BUILD SCRIPT ERROR: Please check the log file for detail, ABORT!"
$ERRSCRIPT || exit $err

echo;echo " .... Build system finished .... "

exit 0

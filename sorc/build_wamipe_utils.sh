#! /usr/bin/env bash
set -eux

build_target=${1:-"all"}

if [ $build_target = "all" ] ; then

source ./machine-setup.sh > /dev/null 2>&1
[[ -z ${comio_ver+x} ]] && source ../versions/build.ver
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
else
  export MOD_PATH=${cwd}/lib/modulefiles
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

fi # $build_target = "all"

cd wamipe_utils.fd/sorc/
./build_all_utils.sh $build_target

if [ $build_target = "install" ] ; then

echo "run ./build_all.sh install"

fi


exit


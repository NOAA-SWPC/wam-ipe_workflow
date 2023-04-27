#! /usr/bin/env bash
set -eux

build_target=${1:-"all"}

if [ $build_target = "all" ] ; then

source ./machine-setup.sh > /dev/null 2>&1
source ../versions/build.ver
cwd=`pwd`

USE_PREINST_LIBS=${USE_PREINST_LIBS:-"true"}
if [ $USE_PREINST_LIBS = true ]; then
  export MOD_PATH=/scratch3/NCEPDEV/nwprod/lib/modulefiles
else
  export MOD_PATH=${cwd}/lib/modulefiles
fi

gsitarget=$target

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

cd gsi.fd/ush/
./build.sh "PRODUCTION" "$cwd/gsi.fd"

elif [ $build_target = "clean" ] ; then

rm -rf gsi.fd/build
rm -f gsi.fd/exec/*

elif [ $build_target = "install" ] ; then

echo "run ./build_all.sh install"

fi

exit


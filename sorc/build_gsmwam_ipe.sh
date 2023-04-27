#! /usr/bin/env bash
set -eux

build_target=${1:-"all"}

if [ $build_target = "all" ] ; then

source ./machine-setup.sh
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

if [ $target = hera ]; then target=hera.intel ; fi

cd gsmwam_ipe.fd/NEMS
gmake -j app=coupledWAM_IPE_SWIO_DATAPOLL build

elif [ $build_target = "clean" ] ; then
cd gsmwam_ipe.fd/NEMS
gmake -j app=coupledWAM_IPE_SWIO_DATAPOLL distclean

elif [ $build_target = "install" ] ; then

echo "run ./build_all.sh install"

fi

exit $?

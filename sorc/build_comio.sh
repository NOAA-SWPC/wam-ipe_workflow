#! /usr/bin/env bash
set -eux

build_target=${1:-"all"}

if [ $build_target = "all" ] ; then

source ./machine-setup.sh > /dev/null 2>&1
[[ -z ${comio_ver+x} ]] && source ../versions/build.ver
cwd=`pwd`

if [ $target = "wcoss2" ] ; then
  module load PrgEnv-intel/$PrgEnv_intel_ver
  module load craype/$craype_ver
  module load intel/$intel_ver
  module load cray-mpich/$cray_mpich_ver
  module load cray-libsci/$cray_libsci_ver
  module load cray-pals/$cray_pals_ver

  module load netcdf/$netcdf_ver
  module load hdf5/$hdf5_ver
  module load pnetcdf/$pnetcdf_ver
else
  module use ../modulefiles
  module load module_base.$target
fi

# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

cd comio.fd

./configure --prefix=`pwd`/install
make && make install

elif [ $build_target = "clean" ] ; then

cd comio.fd

make clean

elif [ $build_target = "install" ] ; then

echo "run ./build_all.sh install"

fi

exit

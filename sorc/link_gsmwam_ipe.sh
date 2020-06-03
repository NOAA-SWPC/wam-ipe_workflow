#!/bin/bash
set -ex

#--make symbolic links for EMC installation and hardcopies for NCO delivery

RUN_ENVIR=${1}
machine=${2}

if [ $# -lt 2 ]; then
    echo '***ERROR*** must specify two arguements: (1) RUN_ENVIR, (2) machine'
    echo ' Syntax: link_gsmwam_ipe.sh ( nco | emc ) ( cray | dell | hera )'
    exit 1
fi

if [ $RUN_ENVIR != emc -a $RUN_ENVIR != nco ]; then
    echo 'Syntax: link_gsmwam_ipe.sh ( nco | emc ) ( cray | dell | hera )'
    exit 1
fi
if [ $machine != cray -a -a $machine != dell -a $machine != hera ]; then
    echo 'Syntax: link_gsmwam_ipe.sh ( nco | emc ) ( cray | dell | hera )'
    exit 1
fi

LINK="ln -fs"
SLINK="ln -fs"
[[ $RUN_ENVIR = nco ]] && LINK="cp -rp"

pwd=$(pwd -P)

#------------------------------
#--model fix fields
#------------------------------
if [ $machine == "cray" ]; then
    FIX_DIR="/gpfs/hps3/emc/global/noscrub/emc.glopara/git/fv3gfs/fix"
elif [ $machine = "dell" ]; then
    FIX_DIR="/gpfs/dell2/emc/modeling/noscrub/emc.glopara/git/fv3gfs/fix"
elif [ $machine = "hera" ]; then
    FIX_DIR="/scratch1/NCEPDEV/swpc/WAM-IPE_DATA/WAM_FIX"
fi
cd ${pwd}/../fix                ||exit 8
for dir in GSM IPE_FIX MED_SPACEWX WAM_gh_L150 ; do
    [[ -d $dir ]] && rm -rf $dir
done
$LINK $FIX_DIR/* .

#---------------------------------------
#--add files from external repositories
#---------------------------------------
cd ${pwd}/../jobs               ||exit 8
    $LINK ../sorc/gfs_post.fd/jobs/JGLOBAL_POST_MANAGER      .
    $LINK ../sorc/gfs_post.fd/jobs/JGLOBAL_NCEPPOST          .
cd ${pwd}/../parm               ||exit 8
    [[ -d post ]] && rm -rf post
    $LINK ../sorc/gfs_post.fd/parm                           post
cd ${pwd}/../scripts            ||exit 8
    $LINK ../sorc/gfs_post.fd/scripts/exgdas_nceppost.sh.ecf .
    $LINK ../sorc/gfs_post.fd/scripts/exgfs_nceppost.sh.ecf  .
    $LINK ../sorc/gfs_post.fd/scripts/exglobal_pmgr.sh.ecf   .
    $LINK ../sorc/ufs_utils.fd/scripts/exemcsfc_global_sfc_prep.sh.ecf .
cd ${pwd}/../ush                ||exit 8
    for file in gfs_nceppost.sh  \
        gfs_transfer.sh  link_crtm_fix.sh  trim_rh.sh fix_precip.sh; do
        $LINK ../sorc/gfs_post.fd/ush/$file                  .
    done
    for file in emcsfc_ice_blend.sh  global_cycle_driver.sh \
        emcsfc_snow.sh  global_chgres_driver.sh  global_cycle.sh \
        global_chgres.sh ; do
        $LINK ../sorc/ufs_utils.fd/ush/$file                  .
    done
cd ${pwd}/../util               ||exit 8
    for file in sub_slurm sub_wcoss_c sub_wcoss_d ; do
        $LINK ../sorc/ufs_utils.fd/util/$file
    done


#-----------------------------------
#--add gfs_wafs link if checked out
if [ -d ${pwd}/gfs_wafs.fd ]; then 
#-----------------------------------
 cd ${pwd}/../jobs               ||exit 8
     $LINK ../sorc/gfs_wafs.fd/jobs/*                         .
 cd ${pwd}/../parm               ||exit 8
     [[ -d wafs ]] && rm -rf wafs
    $LINK ../sorc/gfs_wafs.fd/parm/wafs                      wafs
 cd ${pwd}/../scripts            ||exit 8
    $LINK ../sorc/gfs_wafs.fd/scripts/*                      .
 cd ${pwd}/../ush                ||exit 8
    $LINK ../sorc/gfs_wafs.fd/ush/*                          .
 cd ${pwd}/../fix                ||exit 8
    $LINK ../sorc/gfs_wafs.fd/fix/*                          .
fi


#------------------------------
#--add GSI/EnKF file
#------------------------------
cd ${pwd}/../jobs               ||exit 8
    $LINK ../sorc/gsi.fd/jobs/JGLOBAL_ANALYSIS           .
    $LINK ../sorc/gsi.fd/jobs/JGLOBAL_ENKF_SELECT_OBS    .
    $LINK ../sorc/gsi.fd/jobs/JGLOBAL_ENKF_INNOVATE_OBS  .
    $LINK ../sorc/gsi.fd/jobs/JGLOBAL_ENKF_UPDATE        .
    $LINK ../sorc/gsi.fd/jobs/JGDAS_ENKF_RECENTER        .
    $LINK ../sorc/gsi.fd/jobs/JGDAS_ENKF_FCST            .
    $LINK ../sorc/gsi.fd/jobs/JGDAS_ENKF_POST            .
cd ${pwd}/../scripts            ||exit 8
    $LINK ../sorc/gsi.fd/scripts/exglobal_analysis.sh.ecf           .
    $LINK ../sorc/gsi.fd/scripts/exglobal_innovate_obs.sh.ecf       .
    $LINK ../sorc/gsi.fd/scripts/exglobal_enkf_innovate_obs.sh.ecf  .
    $LINK ../sorc/gsi.fd/scripts/exglobal_enkf_update.sh.ecf        .
    $LINK ../sorc/gsi.fd/scripts/exglobal_enkf_recenter.sh.ecf      .
    $LINK ../sorc/gsi.fd/scripts/exglobal_enkf_fcst.sh.ecf          .
    $LINK ../sorc/gsi.fd/scripts/exglobal_enkf_post.sh.ecf          .
cd ${pwd}/../fix                ||exit 8
    [[ -d fix_gsi ]] && rm -rf fix_gsi
    $LINK ../sorc/gsi.fd/fix  fix_gsi


#------------------------------
#--add DA Monitor file (NOTE: ensure to use correct version)
#------------------------------
cd ${pwd}/../fix                ||exit 8
    [[ -d gdas ]] && rm -rf gdas
    mkdir -p gdas
    cd gdas
    $LINK ../../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gdas.v1.0.0/fix/gdas_minmon_cost.txt            .
    $LINK ../../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gdas.v1.0.0/fix/gdas_minmon_gnorm.txt           .
    $LINK ../../sorc/gsi.fd/util/Ozone_Monitor/nwprod/gdas_oznmon.v2.0.0/fix/gdas_oznmon_base.tar            .
    $LINK ../../sorc/gsi.fd/util/Ozone_Monitor/nwprod/gdas_oznmon.v2.0.0/fix/gdas_oznmon_satype.txt          .
    $LINK ../../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/fix/gdas_radmon_base.tar         .
    $LINK ../../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/fix/gdas_radmon_satype.txt       .
    $LINK ../../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/fix/gdas_radmon_scaninfo.txt     .
cd ${pwd}/../jobs               ||exit 8
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gdas.v1.0.0/jobs/JGDAS_VMINMON                     .
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gfs.v1.0.0/jobs/JGFS_VMINMON                       .
    $LINK ../sorc/gsi.fd/util/Ozone_Monitor/nwprod/gdas_oznmon.v2.0.0/jobs/JGDAS_VERFOZN                     .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/jobs/JGDAS_VERFRAD                  .
cd ${pwd}/../parm               ||exit 8
    [[ -d mon ]] && rm -rf mon
    mkdir -p mon
    cd mon
    $LINK ../../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/parm/gdas_radmon.parm            da_mon.parm
#   $LINK ../../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gdas.v1.0.0/parm/gdas_minmon.parm               .
#   $LINK ../../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gfs.v1.0.0/parm/gfs_minmon.parm                 .
    $LINK ../../sorc/gsi.fd/util/Ozone_Monitor/nwprod/gdas_oznmon.v2.0.0/parm/gdas_oznmon.parm               .
#   $LINK ../../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/parm/gdas_radmon.parm            .
cd ${pwd}/../scripts            ||exit 8
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gdas.v1.0.0/scripts/exgdas_vrfminmon.sh.ecf        .
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/gfs.v1.0.0/scripts/exgfs_vrfminmon.sh.ecf          .
    $LINK ../sorc/gsi.fd/util/Ozone_Monitor/nwprod/gdas_oznmon.v2.0.0/scripts/exgdas_vrfyozn.sh.ecf          .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/gdas_radmon.v3.0.0/scripts/exgdas_vrfyrad.sh.ecf       .
cd ${pwd}/../ush                ||exit 8
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/minmon_shared.v1.0.1/ush/minmon_xtrct_costs.pl     .
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/minmon_shared.v1.0.1/ush/minmon_xtrct_gnorms.pl    .
    $LINK ../sorc/gsi.fd/util/Minimization_Monitor/nwprod/minmon_shared.v1.0.1/ush/minmon_xtrct_reduct.pl    .
    $LINK ../sorc/gsi.fd/util/Ozone_Monitor/nwprod/oznmon_shared.v2.0.0/ush/ozn_xtrct.sh                     .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/ush/radmon_ck_stdout.sh           .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/ush/radmon_err_rpt.sh             .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/ush/radmon_verf_angle.sh          .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/ush/radmon_verf_bcoef.sh          .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/ush/radmon_verf_bcor.sh           .
    $LINK ../sorc/gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/ush/radmon_verf_time.sh           .
    

#------------------------------
#--link executables 
#------------------------------

cd $pwd/../exec
executable=global_gsmwam_ipe.x
[[ -s $executable ]] && rm -f $executable
$LINK ../sorc/gsmwam_ipe.fd/NEMS/exe/NEMS.x $executable

[[ -s gfs_ncep_post ]] && rm -f gfs_ncep_post
$LINK ../sorc/gfs_post.fd/exec/ncep_post gfs_ncep_post

if [ -d ${pwd}/gfs_wafs.fd ]; then 
    for wafsexe in wafs_awc_wafavn  wafs_blending  wafs_cnvgrib2  wafs_gcip  wafs_makewafs  wafs_setmissing; do
        [[ -s $wafsexe ]] && rm -f $wafsexe
        $LINK ../sorc/gfs_wafs.fd/exec/$wafsexe .
    done
fi

for ufs_utilsexe in \
     chgres_cube.exe   fregrid           make_hgrid           nemsio_get    shave.x \
     emcsfc_ice_blend  fregrid_parallel  make_hgrid_parallel  nemsio_read \
     emcsfc_snow2mdl   global_chgres     make_solo_mosaic     nst_tf_chg.x \
     filter_topo       global_cycle      mkgfsnemsioctl       orog.x ; do
    [[ -s $ufs_utilsexe ]] && rm -f $ufs_utilsexe
    $LINK ../sorc/ufs_utils.fd/exec/$ufs_utilsexe .
done

for gsiexe in  global_gsi.x global_enkf.x calc_increment_ens.x  getsfcensmeanp.x  getsigensmeanp_smooth.x  \
    getsigensstatp.x  nc_diag_cat_serial.x nc_diag_cat.x recentersigp.x oznmon_horiz.x oznmon_time.x \
    radmon_angle.x radmon_bcoef.x radmon_bcor.x radmon_time.x ;do
    [[ -s $gsiexe ]] && rm -f $gsiexe
    $LINK ../sorc/gsi.fd/exec/$gsiexe .
done


#------------------------------
#--link source code directories
#------------------------------

cd ${pwd}/../sorc   ||   exit 8
    $SLINK gsi.fd/util/EnKF/gfs/src/calc_increment_ens.fd                                  calc_increment_ens.fd
    $SLINK gsi.fd/util/EnKF/gfs/src/getsfcensmeanp.fd                                      getsfcensmeanp.fd
    $SLINK gsi.fd/util/EnKF/gfs/src/getsigensmeanp_smooth.fd                               getsigensmeanp_smooth.fd
    $SLINK gsi.fd/util/EnKF/gfs/src/getsigensstatp.fd                                      getsigensstatp.fd
    $SLINK gsi.fd/src                                                                      global_enkf.fd
    $SLINK gsi.fd/src                                                                      global_gsi.fd
    $SLINK gsi.fd/util/Ozone_Monitor/nwprod/oznmon_shared.v2.0.0/sorc/oznmon_horiz.fd      oznmon_horiz.fd
    $SLINK gsi.fd/util/Ozone_Monitor/nwprod/oznmon_shared.v2.0.0/sorc/oznmon_time.fd       oznmon_time.fd
    $SLINK gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/sorc/verf_radang.fd    radmon_angle.fd
    $SLINK gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/sorc/verf_radbcoef.fd  radmon_bcoef.fd
    $SLINK gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/sorc/verf_radbcor.fd   radmon_bcor.fd 
    $SLINK gsi.fd/util/Radiance_Monitor/nwprod/radmon_shared.v3.0.0/sorc/verf_radtime.fd   radmon_time.fd 
    $SLINK gsi.fd/util/EnKF/gfs/src/recentersigp.fd                                        recentersigp.fd

    $SLINK gfs_post.fd/sorc/ncep_post.fd                                                   gfs_ncep_post.fd

    $SLINK ufs_utils.fd/sorc/fre-nctools.fd/tools/shave.fd                                 shave.fd
    for prog in filter_topo fregrid make_hgrid make_solo_mosaic ; do
        $SLINK ufs_utils.fd/sorc/fre-nctools.fd/tools/$prog                                ${prog}.fd                                
    done
    for prog in  chgres_cube.fd       global_cycle.fd   nemsio_read.fd \
                 emcsfc_ice_blend.fd  mkgfsnemsioctl.fd  nst_tf_chg.fd \
                 emcsfc_snow2mdl.fd   global_chgres.fd  nemsio_get.fd      orog.fd ;do
        $SLINK ufs_utils.fd/sorc/$prog                                                     $prog
    done


    if [ -d ${pwd}/gfs_wafs.fd ]; then 
        $SLINK gfs_wafs.fd/sorc/wafs_awc_wafavn.fd                                              wafs_awc_wafavn.fd
        $SLINK gfs_wafs.fd/sorc/wafs_blending.fd                                                wafs_blending.fd
        $SLINK gfs_wafs.fd/sorc/wafs_cnvgrib2.fd                                                wafs_cnvgrib2.fd
        $SLINK gfs_wafs.fd/sorc/wafs_gcip.fd                                                    wafs_gcip.fd
        $SLINK gfs_wafs.fd/sorc/wafs_makewafs.fd                                                wafs_makewafs.fd
        $SLINK gfs_wafs.fd/sorc/wafs_setmissing.fd                                              wafs_setmissing.fd
    fi


#------------------------------
#--choose dynamic config.base for EMC installation 
#--choose static config.base for NCO installation 
cd $pwd/../parm/config
[[ -s config.base ]] && rm -f config.base 
if [ $RUN_ENVIR = nco ] ; then
 cp -p config.base.nco.static config.base
else
 cp -p config.base.emc.dyn config.base
fi
#------------------------------


exit 0

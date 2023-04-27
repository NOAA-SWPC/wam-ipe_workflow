#!/bin/bash
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exwamipe_dbnalert.sh
# Script description:  Produces DBN alerts
#
# Author: Adam Kubaryk      Org: NCEP/SWPC     Date: 2023-04-27
#
# Abstract: This script issues DBNet alerts.
#
# $Id$
#
# Attributes:
#   Language: bash shell
#   Machine: WCOSS2
#
################################################################################

cd $COMOUT

for ymd_h in $(ls ${CDUMP}.*.nc | grep -oP "\d{8}_\d\d" | sort | uniq); do echo tar cf wfs.${cycle}.${ymd_h}.tar $(ls ${CDUMP}.*${ymd_h}*.nc); done | xargs --max-procs=28 -I{} bash -c {}

filestoalert=$(find $COMOUT -name '*.tar' | sort -n)
for filetoalert in $filestoalert ; do
    $DBNROOT/bin/dbn_alert MODEL WFS $job $filetoalert
done

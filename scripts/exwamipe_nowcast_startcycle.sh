#!/bin/bash
################################################################################
####  UNIX Script Documentation Block
#                      .                                             .
# Script name:         exwamipe_startcycle.sh
# Script description:  Check for required input data for WRS analysis job
#
# Author: Adam Kubaryk      Org: NCEP/SWPC     Date: 2023-04-27
#
# Abstract: This script waits for $IPEGES to exist, which should always be the
#           final generated file at the initialization datetime for the current
#           WRS cycle.
#
# $Id$
#
# Attributes:
#   Language: bash shell
#   Machine: WCOSS2/Hera
#
################################################################################

set -ax

IPEGES=${IPEGES:-${COMIN_GES}/${PREFIX}IPE_State.apex.${FDATE}00.h5}

while [ ! -f $IPEGES ] ; do
    sleep 30
done

exit $?

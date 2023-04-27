#!/bin/sh

# Checkout, build, setup and execute the workflow

set -ex

pslot="hysell"
expdir="/lfs/h1/swpc/wam/noscrub/$USER/exp"
comrot="/lfs/h1/swpc/ptmp/$USER"
idate="2022052512"
edate="2023052512"

######################################
# USER NEED NOT MODIFY BELOW THIS LINE
######################################

[[ -d $expdir/$pslot ]] && rm -rf $expdir/$pslot
#[[ -d $comrot/$pslot ]] && rm -rf $comrot/$pslot

python setup_expt.py --pslot $pslot --comrot $comrot --expdir $expdir \
                     --idate $idate --edate $edate --configdir ../../parm/config
python setup_workflow.py --expdir $expdir/$pslot

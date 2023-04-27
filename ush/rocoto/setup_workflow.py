#!/usr/bin/env python

'''
    PROGRAM:
        Create the ROCOTO workflow given the configuration of the WFS parallel

    AUTHOR:
        Rahul.Mahajan
        rahul.mahajan@noaa.gov

    FILE DEPENDENCIES:
        1. config files for the parallel; e.g. config.base, config.fcst[.wfs], etc.
        Without these dependencies, the script will fail

    OUTPUT:
        1. PSLOT.xml: XML workflow
        2. PSLOT.crontab: crontab for ROCOTO run command
'''
from __future__ import division
from __future__ import print_function

import os
import sys
import re
import numpy as np
from datetime import datetime, timedelta
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from collections import OrderedDict
import rocoto
import workflow_utils as wfu

def main():
    parser = ArgumentParser(description='Setup XML workflow and CRONTAB for a WFS parallel.', formatter_class=ArgumentDefaultsHelpFormatter)
    parser.add_argument('--expdir', help='full path to experiment directory containing config files', type=str, required=False, default=os.environ['PWD'])
    args = parser.parse_args()

    configs = wfu.get_configs(args.expdir)

    _base = wfu.config_parser([wfu.find_config('config.base', configs)])

    if not os.path.samefile(args.expdir, _base['EXPDIR']):
        print('MISMATCH in experiment directories!')
        print('config.base: EXPDIR = %s' % repr(_base['EXPDIR']))
        print('input arg:     --expdir = %s' % repr(args.expdir))
        sys.exit(1)

    wfs_steps = ['prep', 'anal', 'fcst', 'arch']
    hyb_steps = ['eobs', 'eomg', 'eupd', 'ecen', 'efcs', 'epos', 'earc']
    metp_steps = ['metp']

    steps = wfs_steps + hyb_steps if _base.get('DOHYBVAR', 'NO') == 'YES' else wfs_steps
    steps = steps + metp_steps if _base.get('DO_METP', 'NO') == 'YES' else steps

    dict_configs = wfu.source_configs(configs, steps)

    # Check and set wfs_cyc specific variables
    if dict_configs['base']['wfs_cyc'] != 0:
        dict_configs['base'] = get_wfs_cyc_dates(dict_configs['base'])

    # First create workflow XML
    create_xml(dict_configs)

    # Next create the crontab
    wfu.create_crontab(dict_configs['base'])

    return


def get_wfs_cyc_dates(base):
    '''
        Generate WFS dates from experiment dates and wfs_cyc choice
    '''

    base_out = base.copy()

    wfs_cyc = base['wfs_cyc']
    sdate = base['SDATE']
    edate = base['EDATE']

    interval_wfs = wfu.get_wfs_interval(wfs_cyc)

    # Set WFS cycling dates
    hrdet = 0
    if wfs_cyc == 1:
        hrinc = 24 - sdate.hour
        hrdet = edate.hour
    elif wfs_cyc == 2:
        if sdate.hour in [0, 12]:
            hrinc = 12
        elif sdate.hour in [6, 18]:
            hrinc = 6
        if edate.hour in [6, 18]:
            hrdet = 6
    elif wfs_cyc == 4:
        hrinc = 6
    sdate_wfs = sdate + timedelta(hours=hrinc)
    edate_wfs = edate - timedelta(hours=hrdet)
    if sdate_wfs > edate:
        print('W A R N I N G!')
        print('Starting date for WFS cycles is after Ending date of experiment')
        print('SDATE = %s,     EDATE = %s' % (sdate.strftime('%Y%m%d%H'), edate.strftime('%Y%m%d%H')))
        print('SDATE_WFS = %s, EDATE_WFS = %s' % (sdate_wfs.strftime('%Y%m%d%H'), edate_wfs.strftime('%Y%m%d%H')))
        wfs_cyc = 0

    base_out['wfs_cyc'] = wfs_cyc
    base_out['SDATE_WFS'] = sdate_wfs
    base_out['EDATE_WFS'] = edate_wfs
    base_out['INTERVAL_WFS'] = interval_wfs

    fhmax_wfs = {}
    for hh in ['00', '06', '12', '18']:
        fhmax_wfs[hh] = base.get('FHMAX_WFS_%s' % hh, 'FHMAX_WFS_00')
    base_out['FHMAX_WFS'] = fhmax_wfs

    return base_out


def get_preamble():
    '''
        Generate preamble for XML
    '''

    strings = []

    strings.append('<?xml version="1.0"?>\n')
    strings.append('<!DOCTYPE workflow\n')
    strings.append('[\n')
    strings.append('\t<!--\n')
    strings.append('\tPROGRAM\n')
    strings.append('\t\tMain workflow manager for cycling Global Forecast System\n')
    strings.append('\n')
    strings.append('\tAUTHOR:\n')
    strings.append('\t\tRahul Mahajan\n')
    strings.append('\t\trahul.mahajan@noaa.gov\n')
    strings.append('\n')
    strings.append('\tNOTES:\n')
    strings.append('\t\tThis workflow was automatically generated at %s\n' % datetime.now())
    strings.append('\t-->\n')

    return ''.join(strings)


def get_definitions(base):
    '''
        Create entities related to the experiment
    '''

    machine = base.get('machine', wfu.detectMachine())
    scheduler = wfu.get_scheduler(machine)

    strings = []

    strings.append('\n')
    strings.append('\t<!-- Experiment parameters such as name, starting, ending dates -->\n')
    strings.append('\t<!ENTITY USER "%s">\n'  % os.environ['USER'])
    strings.append('\t<!ENTITY PSLOT "%s">\n' % base['PSLOT'])
    strings.append('\t<!ENTITY job "%s">\n'   % base['PSLOT'])
    strings.append('\t<!ENTITY SDATE "%s">\n' % base['SDATE'].strftime('%Y%m%d%H%M'))
    strings.append('\t<!ENTITY EDATE "%s">\n' % base['EDATE'].strftime('%Y%m%d%H%M'))

    if base['wfs_cyc'] != 0:
        strings.append(get_wfs_dates(base))
        strings.append('\n')

    strings.append('\t<!-- Run Envrionment -->\n')
    strings.append('\t<!ENTITY RUN_ENVIR "%s">\n' % base['RUN_ENVIR'])
    strings.append('\n')
    strings.append('\t<!-- Experiment and Rotation directory -->\n')
    strings.append('\t<!ENTITY EXPDIR "%s">\n'   % base['EXPDIR'])
    strings.append('\t<!ENTITY COMROOT "%s">\n'  % base['COMROOT'])
    strings.append('\t<!ENTITY DATAROOT "%s">\n' % base['DATAROOT'])
    strings.append('\n')
    strings.append('\t<!-- Directories for driving the workflow -->\n')
    strings.append('\t<!ENTITY HOMEwfs  "%s">\n' % base['HOMEwfs'])
    strings.append('\t<!ENTITY JOBS_DIR "%s">\n' % base['BASE_JOB'])
    strings.append('\t<!ENTITY DMPDIR   "%s">\n' % base['DMPDIR'])
    strings.append('\n')
    strings.append('\t<!-- Machine related entities -->\n')
    strings.append('\t<!ENTITY ACCOUNT    "%s">\n' % base['ACCOUNT'])

    strings.append('\t<!ENTITY QUEUE      "%s">\n' % base['QUEUE'])
    strings.append('\t<!ENTITY QUEUE_ARCH "%s">\n' % base['QUEUE_ARCH'])
    if scheduler in ['slurm']:
        strings.append('\t<!ENTITY PARTITION_ARCH "%s">\n' % base['QUEUE_ARCH'])
    strings.append('\t<!ENTITY SCHEDULER  "%s">\n' % scheduler)
    strings.append('\n')
    strings.append('\t<!-- Toggle HPSS archiving -->\n')
    strings.append('\t<!ENTITY ARCHIVE_TO_HPSS "YES">\n')
    strings.append('\n')
    strings.append('\t<!-- ROCOTO parameters that control workflow -->\n')
    strings.append('\t<!ENTITY CYCLETHROTTLE "3">\n')
    strings.append('\t<!ENTITY TASKTHROTTLE  "25">\n')
    strings.append('\t<!ENTITY MAXTRIES      "2">\n')
    strings.append('\n')

    return ''.join(strings)


def get_wfs_dates(base):
    '''
        Generate WFS dates entities
    '''

    strings = []

    strings.append('\n')
    strings.append('\t<!-- Starting and ending dates for WFS cycle -->\n')
    strings.append('\t<!ENTITY SDATE_WFS    "%s">\n' % base['SDATE_WFS'].strftime('%Y%m%d%H%M'))
    strings.append('\t<!ENTITY EDATE_WFS    "%s">\n' % base['EDATE_WFS'].strftime('%Y%m%d%H%M'))
    strings.append('\t<!ENTITY INTERVAL_WFS "%s">\n' % base['INTERVAL_WFS'])

    return ''.join(strings)


def get_wdaswfs_resources(dict_configs, cdump='wdas'):
    '''
        Create WDAS or WFS resource entities
    '''

    base = dict_configs['base']
    machine = base.get('machine', wfu.detectMachine())
    scheduler = wfu.get_scheduler(machine)
    do_bufrsnd = base.get('DO_BUFRSND', 'NO').upper()
    do_gempak = base.get('DO_GEMPAK', 'NO').upper()
    do_awips = base.get('DO_AWIPS', 'NO').upper()
    do_metp = base.get('DO_METP', 'NO').upper()

    tasks = ['prep', 'anal', 'fcst', 'arch']

    if cdump in ['wfs'] and do_bufrsnd in ['Y', 'YES']:
        tasks += ['postsnd']
    if cdump in ['wfs'] and do_gempak in ['Y', 'YES']:
        tasks += ['gempak']
    if cdump in ['wfs'] and do_awips in ['Y', 'YES']:
        tasks += ['awips']
    if cdump in ['wfs'] and do_metp in ['Y', 'YES']:
        tasks += ['metp']

    dict_resources = OrderedDict()

    for task in tasks:

        cfg = dict_configs[task]

        wtimestr, resstr, queuestr, memstr, natstr = wfu.get_resources(machine, cfg, task, cdump=cdump)
        taskstr = '%s_%s' % (task.upper(), cdump.upper())

        strings = []
        strings.append('\t<!ENTITY QUEUE_%s     "%s">\n' % (taskstr, queuestr))
        if scheduler in ['slurm'] and task in ['arch']:
            strings.append('\t<!ENTITY PARTITION_%s "&PARTITION_ARCH;">\n' % taskstr )
        strings.append('\t<!ENTITY WALLTIME_%s  "%s">\n' % (taskstr, wtimestr))
        strings.append('\t<!ENTITY RESOURCES_%s "%s">\n' % (taskstr, resstr))
        if len(memstr) != 0:
            strings.append('\t<!ENTITY MEMORY_%s    "%s">\n' % (taskstr, memstr))
        strings.append('\t<!ENTITY NATIVE_%s    "%s">\n' % (taskstr, natstr))

        dict_resources['%s%s' % (cdump, task)] = ''.join(strings)

    return dict_resources


def get_hyb_resources(dict_configs):
    '''
        Create hybrid resource entities
    '''

    base = dict_configs['base']
    machine = base.get('machine', wfu.detectMachine())
    scheduler = wfu.get_scheduler(machine)
    lobsdiag_forenkf = base.get('lobsdiag_forenkf', '.false.').upper()
    eupd_cyc= base.get('EUPD_CYC', 'wdas').upper()

    dict_resources = OrderedDict()

    # These tasks can be run in either or both cycles
    tasks1 = ['eobs', 'eomg', 'eupd']
    if lobsdiag_forenkf in ['.T.', '.TRUE.']:
        tasks.remove('eomg')

    if eupd_cyc in ['BOTH']:
        cdumps = ['wfs', 'wdas']
    elif eupd_cyc in ['WFS']:
        cdumps = ['wfs']
    elif eupd_cyc in ['WDAS']:
        cdumps = ['wdas']

    for cdump in cdumps:
        for task in tasks1:

            cfg = dict_configs['eobs'] if task in ['eomg'] else dict_configs[task]

            wtimestr, resstr, queuestr, memstr, natstr = wfu.get_resources(machine, cfg, task, cdump=cdump)

            taskstr = '%s_%s' % (task.upper(), cdump.upper())

            strings = []

            strings.append('\t<!ENTITY QUEUE_%s     "%s">\n' % (taskstr, queuestr))
            strings.append('\t<!ENTITY WALLTIME_%s  "%s">\n' % (taskstr, wtimestr))
            strings.append('\t<!ENTITY RESOURCES_%s "%s">\n' % (taskstr, resstr))
            if len(memstr) != 0:
                strings.append('\t<!ENTITY MEMORY_%s    "%s">\n' % (taskstr, memstr))
            strings.append('\t<!ENTITY NATIVE_%s    "%s">\n' % (taskstr, natstr))

            dict_resources['%s%s' % (cdump, task)] = ''.join(strings)


    # These tasks are always run as part of the WDAS cycle
    cdump = 'wdas'
    tasks2 = ['ecen', 'efcs', 'epos', 'earc']
    for task in tasks2:

        cfg = dict_configs[task]

        wtimestr, resstr, queuestr, memstr, natstr = wfu.get_resources(machine, cfg, task, cdump=cdump)

        taskstr = '%s_%s' % (task.upper(), cdump.upper())

        strings = []
        strings.append('\t<!ENTITY QUEUE_%s     "%s">\n' % (taskstr, queuestr))
        if scheduler in ['slurm'] and task in ['earc']:
            strings.append('\t<!ENTITY PARTITION_%s "&PARTITION_ARCH;">\n' % taskstr )
        strings.append('\t<!ENTITY WALLTIME_%s  "%s">\n' % (taskstr, wtimestr))
        strings.append('\t<!ENTITY RESOURCES_%s "%s">\n' % (taskstr, resstr))
        if len(memstr) != 0:
            strings.append('\t<!ENTITY MEMORY_%s    "%s">\n' % (taskstr, memstr))
        strings.append('\t<!ENTITY NATIVE_%s    "%s">\n' % (taskstr, natstr))

        dict_resources['%s%s' % (cdump, task)] = ''.join(strings)

    return dict_resources


def get_wdaswfs_tasks(dict_configs, cdump='wdas'):
    '''
        Create WDAS or WFS tasks
    '''

    envars = []
    if wfu.get_scheduler(wfu.detectMachine()) in ['slurm']:
        envars.append(rocoto.create_envar(name='SLURM_SET', value='YES'))
    envars.append(rocoto.create_envar(name='RUN_ENVIR', value='&RUN_ENVIR;'))
    envars.append(rocoto.create_envar(name='HOMEwfs', value='&HOMEwfs;'))
    envars.append(rocoto.create_envar(name='EXPDIR', value='&EXPDIR;'))
    envars.append(rocoto.create_envar(name='CDATE', value='<cyclestr>@Y@m@d@H</cyclestr>'))
    envars.append(rocoto.create_envar(name='CDUMP', value='%s' % cdump))
    envars.append(rocoto.create_envar(name='PDY', value='<cyclestr>@Y@m@d</cyclestr>'))
    envars.append(rocoto.create_envar(name='cyc', value='<cyclestr>@H</cyclestr>'))
    envars.append(rocoto.create_envar(name='COMROOT', value='&COMROOT;'))
    envars.append(rocoto.create_envar(name='DATAROOT', value='&COMROOT;/RUNDIRS/&PSLOT;'))

    base = dict_configs['base']
    wfs_cyc = base.get('wfs_cyc', 0)
    dohybvar = base.get('DOHYBVAR', 'NO').upper()
    eupd_cyc = base.get('EUPD_CYC', 'wdas').upper()
    do_bufrsnd = base.get('DO_BUFRSND', 'NO').upper()
    do_gempak = base.get('DO_GEMPAK', 'NO').upper()
    do_awips = base.get('DO_AWIPS', 'NO').upper()
    do_metp = base.get('DO_METP', 'NO').upper()
    dumpsuffix = base.get('DUMP_SUFFIX', '')

    dict_tasks = OrderedDict()

    # prep
    deps = []
    dep_dict = {'type': 'task', 'name': '%sfcst' % 'wdas', 'offset': '-06:00:00'}
    deps.append(rocoto.add_dependency(dep_dict))
    data = '&COMROOT;/wdas.@Y@m@d/@H/wdas.t@Hz.atmf06'
    dep_dict = {'type': 'data', 'data': data, 'offset': '-06:00:00'}
    deps.append(rocoto.add_dependency(dep_dict))
    data = '&DMPDIR;/%s%s.@Y@m@d/@H/%s.t@Hz.updated.status.tm00.bufr_d' % ("g{}".format(cdump[1:]), dumpsuffix, "g{}".format(cdump[1:]))
    dep_dict = {'type': 'data', 'data': data}
    deps.append(rocoto.add_dependency(dep_dict))
    dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)

    wfs_enkf = True if eupd_cyc in ['BOTH', 'WFS'] and dohybvar in ['Y', 'YES'] else False

    if wfs_enkf and cdump in ['wfs']:
        if wfs_cyc == 4:
            task = wfu.create_wf_task('prep', cdump=cdump, envar=envars, dependency=dependencies)
        else:
            task = wfu.create_wf_task('prep', cdump=cdump, envar=envars, dependency=dependencies, cycledef='wdas')

    else:
        task = wfu.create_wf_task('prep', cdump=cdump, envar=envars, dependency=dependencies)

    dict_tasks['%sprep' % cdump] = task

    # anal
    deps = []
    dep_dict = {'type': 'task', 'name': '%sprep' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    if dohybvar in ['y', 'Y', 'yes', 'YES']:
        dep_dict = {'type': 'metatask', 'name': '%sepmn' % 'wdas', 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    else:
        dependencies = rocoto.create_dependency(dep=deps)
    task = wfu.create_wf_task('anal', cdump=cdump, envar=envars, dependency=dependencies)

    dict_tasks['%sanal' % cdump] = task

    # fcst
    deps = []
    dep_dict = {'type': 'task', 'name': '%sanal' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    if cdump in ['wdas']:
        dep_dict = {'type': 'cycleexist', 'condition': 'not', 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)
    elif cdump in ['wfs']:
        dependencies = rocoto.create_dependency(dep=deps)
    task = wfu.create_wf_task('fcst', cdump=cdump, envar=envars, dependency=dependencies)

    dict_tasks['%sfcst' % cdump] = task

    # arch
    deps = []
    dep_dict = {'type': 'task', 'name': '%svrfy' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    dep_dict = {'type': 'streq', 'left': '&ARCHIVE_TO_HPSS;', 'right': 'YES'}
    deps.append(rocoto.add_dependency(dep_dict))
    dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    task = wfu.create_wf_task('arch', cdump=cdump, envar=envars, dependency=dependencies)

    dict_tasks['%sarch' % cdump] = task

    return dict_tasks


def get_hyb_tasks(dict_configs, cycledef='enkf'):
    '''
        Create Hybrid tasks
    '''

    # Determine groups based on ensemble size and grouping
    base = dict_configs['base']
    nens = base['NMEM_ENKF']
    lobsdiag_forenkf = base.get('lobsdiag_forenkf', '.false.').upper()
    eupd_cyc = base.get('EUPD_CYC', 'wdas').upper()

    eobs = dict_configs['eobs']
    nens_eomg = eobs['NMEM_EOMGGRP']
    neomg_grps = nens // nens_eomg
    EOMGGROUPS = ' '.join(['%02d' % x for x in range(1, neomg_grps + 1)])

    efcs = dict_configs['efcs']
    nens_efcs = efcs['NMEM_EFCSGRP']
    nefcs_grps = nens // nens_efcs
    EFCSGROUPS = ' '.join(['%02d' % x for x in range(1, nefcs_grps + 1)])

    earc = dict_configs['earc']
    nens_earc = earc['NMEM_EARCGRP']
    nearc_grps = nens // nens_earc
    EARCGROUPS = ' '.join(['%02d' % x for x in range(0, nearc_grps + 1)])

    envars = []
    if wfu.get_scheduler(wfu.detectMachine()) in ['slurm']:
       envars.append(rocoto.create_envar(name='SLURM_SET', value='YES'))
    envars.append(rocoto.create_envar(name='RUN_ENVIR', value='&RUN_ENVIR;'))
    envars.append(rocoto.create_envar(name='HOMEwfs', value='&HOMEwfs;'))
    envars.append(rocoto.create_envar(name='EXPDIR', value='&EXPDIR;'))
    envars.append(rocoto.create_envar(name='CDATE', value='<cyclestr>@Y@m@d@H</cyclestr>'))
    #envars.append(rocoto.create_envar(name='CDUMP', value='%s' % cdump))
    envars.append(rocoto.create_envar(name='PDY', value='<cyclestr>@Y@m@d</cyclestr>'))
    envars.append(rocoto.create_envar(name='cyc', value='<cyclestr>@H</cyclestr>'))

    ensgrp = rocoto.create_envar(name='ENSGRP', value='#grp#')

    dict_tasks = OrderedDict()

    if eupd_cyc in ['BOTH']:
        cdumps = ['wfs', 'wdas']
    elif eupd_cyc in ['WFS']:
        cdumps = ['wfs']
    elif eupd_cyc in ['WDAS']:
        cdumps = ['wdas']

    for cdump in cdumps:

        envar_cdump = rocoto.create_envar(name='CDUMP', value='%s' % cdump)
        envars1 = envars + [envar_cdump]

        # eobs
        deps = []
        dep_dict = {'type': 'task', 'name': '%sprep' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dep_dict = {'type': 'metatask', 'name': '%sepmn' % 'wdas', 'offset': '-06:00:00'}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
        task = wfu.create_wf_task('eobs', cdump=cdump, envar=envars1, dependency=dependencies, cycledef=cycledef)

        dict_tasks['%seobs' % cdump] = task

        # eomn, eomg
        if lobsdiag_forenkf in ['.F.', '.FALSE.']:
            deps = []
            dep_dict = {'type': 'task', 'name': '%seobs' % cdump}
            deps.append(rocoto.add_dependency(dep_dict))
            dependencies = rocoto.create_dependency(dep=deps)
            eomgenvars= envars1 + [ensgrp]
            task = wfu.create_wf_task('eomg', cdump=cdump, envar=eomgenvars, dependency=dependencies,
                                      metatask='eomn', varname='grp', varval=EOMGGROUPS, cycledef=cycledef)

            dict_tasks['%seomn' % cdump] = task

        # eupd
        deps = []
        if lobsdiag_forenkf in ['.F.', '.FALSE.']:
            dep_dict = {'type': 'metatask', 'name': '%seomn' % cdump}
        else:
            dep_dict = {'type': 'task', 'name': '%seobs' % cdump}
        deps.append(rocoto.add_dependency(dep_dict))
        dependencies = rocoto.create_dependency(dep=deps)
        task = wfu.create_wf_task('eupd', cdump=cdump, envar=envars1, dependency=dependencies, cycledef=cycledef)

        dict_tasks['%seupd' % cdump] = task

    # All hybrid tasks beyond this point are always executed in the WDAS cycle
    cdump = 'wdas'
    envar_cdump = rocoto.create_envar(name='CDUMP', value='%s' % cdump)
    envars1 = envars + [envar_cdump]
    cdump_eupd = 'wfs' if eupd_cyc in ['WFS'] else 'wdas'

    # ecen
    deps = []
    dep_dict = {'type': 'task', 'name': '%sanal' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    dep_dict = {'type': 'task', 'name': '%seupd' % cdump_eupd}
    deps.append(rocoto.add_dependency(dep_dict))
    dependencies = rocoto.create_dependency(dep_condition='and', dep=deps)
    task = wfu.create_wf_task('ecen', cdump=cdump, envar=envars1, dependency=dependencies, cycledef=cycledef)

    dict_tasks['%secen' % cdump] = task

    # efmn, efcs
    deps = []
    dep_dict = {'type': 'task', 'name': '%secen' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    dep_dict = {'type': 'cycleexist', 'condition': 'not', 'offset': '-06:00:00'}
    deps.append(rocoto.add_dependency(dep_dict))
    dependencies = rocoto.create_dependency(dep_condition='or', dep=deps)
    efcsenvars = envars1 + [ensgrp]
    task = wfu.create_wf_task('efcs', cdump=cdump, envar=efcsenvars, dependency=dependencies,
                              metatask='efmn', varname='grp', varval=EFCSGROUPS, cycledef=cycledef)

    dict_tasks['%sefmn' % cdump] = task

    # epmn, epos
    deps = []
    dep_dict = {'type': 'metatask', 'name': '%sefmn' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    dependencies = rocoto.create_dependency(dep=deps)
    fhrgrp = rocoto.create_envar(name='FHRGRP', value='#grp#')
    fhrlst = rocoto.create_envar(name='FHRLST', value='#lst#')
    eposenvars = envars1 + [fhrgrp] + [fhrlst]
    varname1, varname2, varname3 = 'grp', 'dep', 'lst'
    varval1, varval2, varval3 = get_eposgroups(dict_configs['epos'], cdump=cdump)
    vardict = {varname2: varval2, varname3: varval3}
    task = wfu.create_wf_task('epos', cdump=cdump, envar=eposenvars, dependency=dependencies,
                              metatask='epmn', varname=varname1, varval=varval1, vardict=vardict)

    dict_tasks['%sepmn' % cdump] = task

    # eamn, earc
    deps = []
    dep_dict = {'type': 'metatask', 'name': '%sepmn' % cdump}
    deps.append(rocoto.add_dependency(dep_dict))
    dependencies = rocoto.create_dependency(dep=deps)
    earcenvars = envars1 + [ensgrp]
    task = wfu.create_wf_task('earc', cdump=cdump, envar=earcenvars, dependency=dependencies,
                              metatask='eamn', varname='grp', varval=EARCGROUPS, cycledef=cycledef)

    dict_tasks['%seamn' % cdump] = task

    return  dict_tasks


def get_workflow_header(base):
    '''
        Create the workflow header block
    '''

    strings = []

    strings.append('\n')
    strings.append(']>\n')
    strings.append('\n')
    strings.append('<workflow realtime="F" scheduler="&SCHEDULER;" cyclethrottle="&CYCLETHROTTLE;" taskthrottle="&TASKTHROTTLE;">\n')
    strings.append('\n')
    strings.append('\t<log verbosity="10"><cyclestr>&EXPDIR;/logs/@Y@m@d@H.log</cyclestr></log>\n')
    strings.append('\n')
    strings.append('\t<!-- Define the cycles -->\n')
    strings.append('\t<cycledef group="enkf" >&SDATE;     &EDATE;     06:00:00</cycledef>\n')
    strings.append('\t<cycledef group="wdas" >&SDATE;     &EDATE;     06:00:00</cycledef>\n')
    if base['wfs_cyc'] != 0:
        strings.append('\t<cycledef group="wfs"  >&SDATE_WFS; &EDATE_WFS; &INTERVAL_WFS;</cycledef>\n')

    strings.append('\n')

    return ''.join(strings)


def get_workflow_footer():
    '''
        Generate workflow footer
    '''

    strings = []
    strings.append('\n</workflow>\n')

    return ''.join(strings)


def get_postgroups(post, cdump='wdas'):

    fhmin = post['FHMIN']
    fhmax = post['FHMAX']
    fhout = post['FHOUT']

    # Get a list of all forecast hours
    if cdump in ['wdas']:
        fhrs = list(range(fhmin, fhmax+fhout, fhout))
    elif cdump in ['wfs']:
        fhmax = np.max([post['FHMAX_WFS_00'],post['FHMAX_WFS_06'],post['FHMAX_WFS_12'],post['FHMAX_WFS_18']])
        fhout = post['FHOUT_WFS']
        fhmax_hf = post['FHMAX_HF_WFS']
        fhout_hf = post['FHOUT_HF_WFS']
        fhrs_hf = list(range(fhmin, fhmax_hf+fhout_hf, fhout_hf))
        fhrs = fhrs_hf + list(range(fhrs_hf[-1]+fhout, fhmax+fhout, fhout))

    npostgrp = post['NPOSTGRP']
    ngrps = npostgrp if len(fhrs) > npostgrp else len(fhrs)

    fhrs = ['f%03d' % f for f in fhrs]
    fhrs = np.array_split(fhrs, ngrps)
    fhrs = [f.tolist() for f in fhrs]

    fhrgrp = ' '.join(['%03d' % x for x in range(0, ngrps+1)])
    fhrdep = ' '.join(['f000'] + [f[-1] for f in fhrs])
    fhrlst = ' '.join(['anl'] + ['_'.join(f) for f in fhrs])

    return fhrgrp, fhrdep, fhrlst

def get_awipsgroups(awips, cdump='wdas'):

    fhmin = awips['FHMIN']
    fhmax = awips['FHMAX']
    fhout = awips['FHOUT']

    # Get a list of all forecast hours
    if cdump in ['wdas']:
        fhrs = list(range(fhmin, fhmax+fhout, fhout))
    elif cdump in ['wfs']:
        fhmax = np.max([awips['FHMAX_WFS_00'],awips['FHMAX_WFS_06'],awips['FHMAX_WFS_12'],awips['FHMAX_WFS_18']])
        fhout = awips['FHOUT_WFS']
        fhmax_hf = awips['FHMAX_HF_WFS']
        fhout_hf = awips['FHOUT_HF_WFS']
        if fhmax > 240:
            fhmax = 240
        if fhmax_hf > 240:
            fhmax_hf = 240
        fhrs_hf = list(range(fhmin, fhmax_hf+fhout_hf, fhout_hf))
        fhrs = fhrs_hf + list(range(fhrs_hf[-1]+fhout, fhmax+fhout, fhout))

    nawipsgrp = awips['NAWIPSGRP']
    ngrps = nawipsgrp if len(fhrs) > nawipsgrp else len(fhrs)

    fhrs = ['f%03d' % f for f in fhrs]
    fhrs = np.array_split(fhrs, ngrps)
    fhrs = [f.tolist() for f in fhrs]

    fhrgrp = ' '.join(['%03d' % x for x in range(0, ngrps)])
    fhrdep = ' '.join([f[-1] for f in fhrs])
    fhrlst = ' '.join(['_'.join(f) for f in fhrs])

    return fhrgrp, fhrdep, fhrlst

def get_eposgroups(epos, cdump='wdas'):

    fhmin = epos['FHMIN_ENKF']
    fhmax = epos['FHMAX_ENKF']
    fhout = epos['FHOUT_ENKF']
    fhrs = list(range(fhmin, fhmax+fhout, fhout))

    neposgrp = epos['NEPOSGRP']
    ngrps = neposgrp if len(fhrs) > neposgrp else len(fhrs)

    fhrs = ['f%03d' % f for f in fhrs]
    fhrs = np.array_split(fhrs, ngrps)
    fhrs = [f.tolist() for f in fhrs]

    fhrgrp = ' '.join(['%03d' % x for x in range(0, ngrps)])
    fhrdep = ' '.join([f[-1] for f in fhrs])
    fhrlst = ' '.join(['_'.join(f) for f in fhrs])

    return fhrgrp, fhrdep, fhrlst


def dict_to_strings(dict_in):

    strings = []
    for key in list(dict_in.keys()):
        strings.append(dict_in[key])
        strings.append('\n')

    return ''.join(strings)


def create_xml(dict_configs):
    '''
        Given an dictionary of sourced config files,
        create the workflow XML
    '''

    from  builtins import any as b_any

    base = dict_configs['base']
    dohybvar = base.get('DOHYBVAR', 'NO').upper()
    wfs_cyc = base.get('wfs_cyc', 0)
    eupd_cyc = base.get('EUPD_CYC', 'wdas').upper()

    # Start collecting workflow pieces
    preamble = get_preamble()
    definitions = get_definitions(base)
    workflow_header = get_workflow_header(base)
    workflow_footer = get_workflow_footer()

    # Get WDAS related entities, resources, workflow
    dict_wdas_resources = get_wdaswfs_resources(dict_configs)
    dict_wdas_tasks = get_wdaswfs_tasks(dict_configs)

    # Get hybrid related entities, resources, workflow
    if dohybvar in ['Y', 'YES']:

        dict_hyb_resources = get_hyb_resources(dict_configs)
        dict_hyb_tasks = get_hyb_tasks(dict_configs)

        # Removes <memory>&MEMORY_JOB_DUMP</memory> post mortem from hyb tasks
        hyp_tasks = {'wdaseobs':'wdaseobs', 'wdaseomg':'wdaseomn', 'wdaseupd':'wdaseupd','wdasecen':'wdasecen','wdasefcs':'wdasefmn','wdasepos':'wdasepmn','wdasearc':'wdaseamn'}
        for each_task, each_resource_string in dict_hyb_resources.items():
            #print each_task,hyp_tasks[each_task]
            #print dict_hyb_tasks[hyp_tasks[each_task]]
            if 'MEMORY' not in each_resource_string:
                if each_task in dict_hyb_tasks:
                    temp_task_string = []
                    for each_line in re.split(r'(\s+)', dict_hyb_tasks[each_task]):
                        if 'memory' not in each_line:
                             temp_task_string.append(each_line)
                    dict_hyb_tasks[each_task] = ''.join(temp_task_string)
                if hyp_tasks[each_task] in dict_hyb_tasks:
                    temp_task_string = []
                    for each_line in re.split(r'(\s+)', dict_hyb_tasks[hyp_tasks[each_task]]):
                        if 'memory' not in each_line:
                             temp_task_string.append(each_line)
                    dict_hyb_tasks[hyp_tasks[each_task]] = ''.join(temp_task_string)

    # Get WFS cycle related entities, resources, workflow
    dict_wfs_resources = get_wdaswfs_resources(dict_configs, cdump='wfs')
    dict_wfs_tasks = get_wdaswfs_tasks(dict_configs, cdump='wfs')

    # Removes <memory>&MEMORY_JOB_DUMP</memory> post mortem from wdas tasks
    for each_task, each_resource_string in dict_wdas_resources.items():
        if each_task not in dict_wdas_tasks:
            continue
        if 'MEMORY' not in each_resource_string:
            temp_task_string = []
            for each_line in re.split(r'(\s+)', dict_wdas_tasks[each_task]):
                if 'memory' not in each_line:
                     temp_task_string.append(each_line)
            dict_wdas_tasks[each_task] = ''.join(temp_task_string)

    # Removes <memory>&MEMORY_JOB_DUMP</memory> post mortem from wfs tasks
    for each_task, each_resource_string in dict_wfs_resources.items():
        if each_task not in dict_wfs_tasks:
            continue
        if 'MEMORY' not in each_resource_string:
            temp_task_string = []
            for each_line in re.split(r'(\s+)', dict_wfs_tasks[each_task]):
                if 'memory' not in each_line:
                     temp_task_string.append(each_line)
            dict_wfs_tasks[each_task] = ''.join(temp_task_string)

    # Put together the XML file
    xmlfile = []

    xmlfile.append(preamble)

    xmlfile.append(definitions)

    xmlfile.append(dict_to_strings(dict_wdas_resources))

    if dohybvar in ['Y', 'YES']:
        xmlfile.append(dict_to_strings(dict_hyb_resources))

    if wfs_cyc != 0:
        xmlfile.append(dict_to_strings(dict_wfs_resources))
    elif wfs_cyc == 0 and dohybvar in ['Y', 'YES'] and eupd_cyc in ['BOTH', 'WFS']:
        xmlfile.append(dict_wfs_resources['wfsprep'])

    xmlfile.append(workflow_header)

    xmlfile.append(dict_to_strings(dict_wdas_tasks))

    if dohybvar in ['Y', 'YES']:
        xmlfile.append(dict_to_strings(dict_hyb_tasks))

    if wfs_cyc != 0:
        xmlfile.append(dict_to_strings(dict_wfs_tasks))
    elif wfs_cyc == 0 and dohybvar in ['Y', 'YES'] and eupd_cyc in ['BOTH', 'WFS']:
        xmlfile.append(dict_wfs_tasks['wfsprep'])
        xmlfile.append('\n')

    xmlfile.append(workflow_footer)

    # Write the XML file
    fh = open('%s/%s.xml' % (base['EXPDIR'], base['PSLOT']), 'w')
    fh.write(''.join(xmlfile))
    fh.close()

    return


if __name__ == '__main__':
    main()
    sys.exit(0)

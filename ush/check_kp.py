#!/usr/bin/env python
import xml.etree.ElementTree as ET
import numpy as np
from datetime import datetime, timedelta
from argparse import ArgumentParser, ArgumentDefaultsHelpFormatter
from glob import glob

WAM_INPUT_FMT = '%Y-%m-%dT%H:%M:%SZ'
KP_LIMIT = 7.9
DEFAULT_PATH = '.'

def parse_wam_input(path, start_date, end_date, date_list):
    kp = []

    days = set([dt.strftime('%Y%m%d') for dt in date_list])
    files = sorted([i for day in days for i in glob('{}/{}/swpc/wam/wam_input*'.format(path, day))])

    file = files[-1]

    try:
        root = ET.parse(file).getroot()
        time = datetime.strptime(root.find('data-item').get('time-tag'), WAM_INPUT_FMT)
        for child in root.findall('data-item'):
            time = datetime.strptime(child.get('time-tag'), WAM_INPUT_FMT)
            if time > start_date and time < end_date:
                kp.append(float(child.find('kp').text))
    except:
        pass

    if np.any(np.array(kp) > KP_LIMIT):
        print('NODA=YES')

def main():
    parser = ArgumentParser( \
               description='Parse Kp to determine if DA should happen', \
               formatter_class=ArgumentDefaultsHelpFormatter \
             )
    parser.add_argument('-s', '--start_date', help='starting date of run (YYYYmmddHH)', type=str, default='2020060100')
    parser.add_argument('-d', '--duration',   help='duration (hours) of run',   type=int, default=48)
    parser.add_argument('-p', '--path',       help='path to input parameters', type=str, default=DEFAULT_PATH)
    args = parser.parse_args()

    start_date = datetime.strptime(args.start_date, '%Y%m%d%H')
    end_date = start_date + timedelta(minutes=args.duration*60)

    date_list = [start_date + timedelta(days=i) for i in range(-1, args.duration // 24)]

    try:
        parse_wam_input(args.path, start_date, end_date, date_list)
    except:
        pass

if __name__ == '__main__':
    main()

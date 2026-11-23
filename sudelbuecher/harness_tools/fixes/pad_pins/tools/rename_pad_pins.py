#!/usr/bin/env python3
"""Rename IHP pad power pins to GF180MCU ocd_io names in the padframe template.
Only inside instances of gf180mcu_ocd_io__* cells or PAD_<s>_<p>_TYPE
placeholders (which parse_config.py replaces by gf180mcu_ocd_io__* types).
constant_block and the (IHP) splitter instance are left alone."""
import re, sys
MAP = {'iovdd': 'DVDD', 'iovss': 'DVSS', 'vdd': 'VDD', 'vss': 'VSS'}
start = re.compile(r'^\s*(gf180mcu_ocd_io__\w+|PAD_\d+_\d+_TYPE)\s+\S+.*\($')
pin = re.compile(r'^(\s*)\.(iovdd|iovss|vdd|vss)\(')
path = sys.argv[1]
out, inside, n = [], False, 0
for line in open(path).read().split('\n'):
    if start.match(line):
        inside = True
    elif inside:
        m = pin.match(line)
        if m:
            line = pin.sub(lambda m: m.group(1) + '.' + MAP[m.group(2)] + '(', line, count=1)
            n += 1
        if line.strip() == ');':
            inside = False
    out.append(line)
open(path, 'w').write('\n'.join(out))
print(f'{path}: {n} pin connections renamed')

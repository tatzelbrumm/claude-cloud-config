#!/usr/bin/env python3
"""Check every gf180mcu_ocd_io__* instance in a padframe verilog against
the PDK verilog port lists: pin names must exist (case-sensitive) and,
with USE_POWER_PINS, every port must be connected."""
import re, sys
pdkv, frame = sys.argv[1], sys.argv[2]
ports = {}
for m in re.finditer(r'module\s+(gf180mcu_ocd_io__\w+)\s*\(([^)]*)\)\s*;', open(pdkv).read()):
    ports[m.group(1)] = [p.strip() for p in m.group(2).split(',') if p.strip()]
txt = re.sub(r'/\*.*?\*/', '', open(frame).read(), flags=re.S)
txt = re.sub(r'//[^\n]*', '', txt)
txt = txt.replace('`ifdef USE_POWER_PINS', '').replace('`endif', '')
bad = 0; count = {}; nets = {}
for m in re.finditer(r'\b(gf180mcu_ocd_\w+)\s+(\w+)\s*(\[[^\]]*\])?\s*\(([^;]*?)\)\s*;', txt, re.S):
    cell, inst, rng, body = m.groups()
    conns = dict(re.findall(r'\.(\w+)\s*\(([^)]*)\)', body))
    count[cell] = count.get(cell, 0) + 1
    if cell not in ports:
        print(f'UNKNOWN CELL {cell} {inst}'); bad += 1; continue
    extra = [p for p in conns if p not in ports[cell]]
    missing = [p for p in ports[cell] if p not in conns]
    if extra or missing:
        bad += 1
        print(f'MISMATCH {cell} {inst}{rng or ""}: not-in-cell={extra} unconnected={missing}')
    key = (cell, tuple((p, conns.get(p, '-').strip()) for p in ('DVDD','DVSS','VDD','VSS') if p in ports[cell]))
    nets[key] = nets.get(key, 0) + 1
print('instances per cell:', dict(sorted(count.items())))
print('power-net patterns (cell, pin->net): count')
for k, v in sorted(nets.items()):
    print(f'  {v:3d}  {k[0]}  ' + ' '.join(f'{p}={n}' for p, n in k[1]))
print('RESULT:', 'FAIL' if bad else 'PASS', f'({bad} problem instances)')
sys.exit(1 if bad else 0)

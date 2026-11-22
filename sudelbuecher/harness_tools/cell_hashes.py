# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
"""Per-cell fingerprint table of a GDS/OASIS file, to compare two builds without moving the files.
usage: python3 cell_hashes.py <layout.gds> [out.tsv]          (needs the `klayout` Python module: pip install klayout)

One line per cell:  cell <TAB> bbox (dbu) <TAB> own shapes <TAB> instances <TAB> sha256 (first 16 hex digits)
The hash covers the cell's OWN content only: per layer/datatype the merged polygons (sorted), texts, and the instances
(child name, transformation, array). It does not descend into children, so one changed cell changes one line, plus the
lines of cells that instantiate it differently. Cell order is sorted by name; layer order by (layer, datatype).
First lines (# ...): file size, sha256 of the whole file, dbu, top cells. Compare two tables with `diff` or
`diff <(cut -f1,5 a.tsv) <(cut -f1,5 b.tsv)`. Needs enough RAM for the layout (the GDS is read whole).
Not a cryptographic equivalence proof of the geometry: merging makes it insensitive to how polygons were split."""
import hashlib, sys
import klayout.db as db

src = sys.argv[1]
out = open(sys.argv[2], 'w') if len(sys.argv) > 2 else sys.stdout
ly = db.Layout()
ly.read(src)
h = hashlib.sha256()
with open(src, 'rb') as f:
    for blk in iter(lambda: f.read(1 << 22), b''):
        h.update(blk)
import os
print(f'# file {os.path.basename(src)} bytes {os.path.getsize(src)} sha256 {h.hexdigest()}', file=out)
print(f'# dbu {ly.dbu} cells {ly.cells()} top {" ".join(sorted(t.name for t in ly.top_cells()))}', file=out)

layers = sorted(((li, ly.get_info(li)) for li in ly.layer_indexes()), key=lambda x: (x[1].layer, x[1].datatype))
for cell in sorted(ly.each_cell(), key=lambda c: c.name):
    hs = hashlib.sha256(); nshapes = 0
    for li, info in layers:
        sh = cell.shapes(li)
        if sh.is_empty():
            continue
        nshapes += sh.size()
        polys = sorted(str(p) for p in db.Region(sh).merged().each())
        texts = sorted(f'{t.string}@{t.trans}' for t in (s.text for s in sh.each(db.Shapes.STexts)))
        hs.update(f'L{info.layer}/{info.datatype}\n'.encode())
        hs.update('\n'.join(polys).encode()); hs.update(b'\nT\n'); hs.update('\n'.join(texts).encode())
    insts = sorted(f'{ly.cell(i.cell_index).name}|{i.cplx_trans}|{i.na}x{i.nb}|{i.a}|{i.b}' for i in cell.each_inst())
    hs.update(b'\nI\n'); hs.update('\n'.join(insts).encode())
    b = cell.bbox()
    print(f'{cell.name}\t{b.left},{b.bottom},{b.right},{b.top}\t{nshapes}\t{len(insts)}\t{hs.hexdigest()[:16]}', file=out)

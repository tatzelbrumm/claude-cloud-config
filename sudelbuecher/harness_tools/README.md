<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# harness_tools

Helpers for moving a big GDS out of a cloud session. Written by the assistant 2026-11-22, tested only on the slot GDS
files of `gf180mcu_ocd_chipalooza` (12 to 210 KB), never yet on a multi-GB file.

- `cell_hashes.py <gds> [out.tsv]` : per-cell fingerprint table (needs `pip install klayout`). Compare the cloud's table
  with one made locally from the unpacked file: `diff <(grep -v '^#' a.tsv | cut -f1,5) <(grep -v '^#' b.tsv | cut -f1,5)`.
  Polygons are merged before hashing, so a shape swallowed by existing geometry changes the shape count (column 3) but
  not the hash: compare columns 1,3,5. Speed on a large file is untested (Python; one `sha256` pass over every polygon).
- `gds_pack.sh <file> <outdir> [chunk]` : `xz -9e`, split (default 90M, GitHub's limit is 100 MB per file), `SHA256SUMS`,
  `MANIFEST.txt`; with `PUSH_URL` and `PUSH_BRANCH` set it force-pushes `<outdir>` as one parentless commit. Needs
  permission from the user for that branch. xz may lower its thread count to stay within its memory limit.
- `gds_unpack.sh <dir> [outdir]` : checks the chunks, joins, decompresses, checks the original's `sha256`. Exit code 1 if
  anything differs. Fetch locally with `git clone --depth 1 -b <branch> <url> dir` (use a `file://` URL for local repos).

Tested: byte-exact round trip with 1 and 5 chunks; fetch from a bare repo; a corrupted chunk makes unpack fail;
the table is deterministic.

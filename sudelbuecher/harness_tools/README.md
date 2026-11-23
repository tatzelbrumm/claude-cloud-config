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

Added 2026-11-23 (for `chipalooza_cloud_task_prompt.txt`):
- `push_logs.sh <url> <branch> <dir> [label]` : append-only commit of the logs to a branch (orphan on first use); skips the
  network when nothing changed. `push_logs_loop.sh` runs it every N seconds in the background.
- `run_step.sh <name> <command...>` : runs one step with log, real exit code and seconds in `/var/tmp/runs/`, then pushes.
- `pad_abutment_check.tcl` : first-call abutment box of the 17 `gf180mcu_ocd_io__*` pad cells, as the harness reads it.
  Tested 2026-11-23 on the ciel-installed PDK `e7a6777`: 17 pads, 0 empty. (A first draft without `box values 0 0 0 0` before
  `getcell` gave empty boxes for all; that was the test's fault, not the PDK's.)
- `gds_pack.sh` now compresses with `xz -6 -T0` by default (`-9e` is several times slower); override with `XZ_OPTS`.
- Chat log of a cloud session: `../chatlog_tools/session_chatlog.sh`.
- `run_chain.sh [step ...]` : the README-order build as one background job (clean-config ... lvs-top), each step through
  `run_step.sh`; stops at the first failure except `CONTINUE_ON` (default projects-gds, lvs-top); skips steps already rc=0, so a
  restart resumes; progress in `/var/tmp/runs/chain.status`. Tested only with a dummy Makefile (failure stop, resume, continue-on).

<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# 2026-11-22: why the gf180mcuD PDK did not install, the fix, and the plan for a cloud Chipalooza build

**Summary written by the assistant. Not a chat log and not verbatim.** Session `session_01XU3KH6BPQEnxokPoJbRoLa`
(Sonnet 5.5). Verbatim log: `../chatlog/2026-11-22_sonnet_gf180_pdk_download_fix.md`.

## Cause
`ciel enable` (v3.3.0) reads its index from `https://fossi-foundation.github.io/ciel-releases`. Since 2026-11 that answers
301 to `http://www-archive.fossi-foundation.org/...`, a name with no DNS record (`[Errno -2] Name or service not known`).
The fallback `--data-source github-releases:...` uses `api.github.com`, which the cloud proxy answers 403 for repositories
outside the session's GitHub scope. Adding `www-archive.fossi-foundation.org` to the environment's allowed hosts is
useless (no DNS). The release tarballs themselves (`github.com/fossi-foundation/ciel-releases/releases/download/<family>-<commit>/<name>.tar.zst`)
download fine (HTTP 302 to release-assets.githubusercontent.com).

## Fix (`main`, 39d01fc)
`parts/ciel.sh`, function `ciel_enable`: default source, then the GitHub API, then a local `static-web` manifest served
on 127.0.0.1:8099 that lists the tarballs found by 1-byte range probes of a candidate-name list. Included only in the
two ciel PDK scripts by `make-setup.sh`; `setup-cloud.sh` (ihp-sg13cmos5l) is byte-identical to before.
Tested in scratch roots: gf180mcu with two libraries, sky130 with one (sky130 has no `sky130_fd_sp_sram`, `sky130_ef_io`,
`sky130_ef_sc_hd`, `sky130_osu_sc_t12/t15/t18` assets). The complete gf180mcuD install (all libraries, 1.1 GB, 4 required
libs present, tech 1.0.588-128-ge7a6777, 0 dangling links) was made by hand in that session. NOT yet verified: a fresh
session on the environment with the new setup script (look for `PDK_RETRY via direct release downloads`, `PDK_OK`, and
that `SETUP_DONE` stays under the ~5 minute cache limit).
The environment's Setup field cannot be edited by the assistant's tool (limit 100 lines; the script has 226): the user pastes it.

## Chipalooza cloud build: findings
- Fork `tatzelbrumm/gf180mcu_ocd_chipalooza` `main` = 78edf00 = merge of upstream d5ad122. Local repo: remote `origin` is
  Tim's upstream, `tatzelfork` is the fork; local `main` = `tatzelfork/main`. Fork branch `minesweeping` (60e30bc) has
  `check_timestamps.py`, `resave_stale_parents.sh`, `make_pdk_overlay.sh`, but also 116 files of regenerated outputs and
  edited run scripts; a local branch `nits` (949e9ed) is not on the fork.
- Flow needs no LibreLane: housekeeping and control layouts are committed `.mag`. 18 slots are all `-` (no user projects).
- Session resources: 4 CPUs, 15 GB RAM, 55 GB disk.
- Local `.designinit` (overlay PDK, Magic 8.3.705) has no cloud counterpart; cloud uses /foss/pdks, Magic 8.3.706.
- Big GDS: `harness_tools/gds_pack.sh` (xz, 90 MB chunks, sha256, optional force-push of one parentless commit to a branch)
  and `gds_unpack.sh`; `cell_hashes.py` for per-cell comparison. Tested only on the slot GDS files (12 to 210 KB).
  Git LFS and the Artifact tool (15 MB) do not fit; the push of a new branch needs the user's explicit permission.
- Task prompt: `../harness_tools/chipalooza_cloud_task_prompt.md`.

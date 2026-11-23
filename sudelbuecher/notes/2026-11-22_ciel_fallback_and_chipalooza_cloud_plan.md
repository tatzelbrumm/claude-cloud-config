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

## Update 2026-11-23: prompt review and launch
- The cloud task prompt (`../harness_tools/chipalooza_cloud_task_prompt.txt`, 67 lines) was reviewed against the harness README/Makefile
  and rewritten. Errors found in the first version: shell variables lost between Bash calls (now `/var/tmp/env.sh`), "working tree
  stays clean" (false), wrong step order (README: wrappers, symbols, gds-slots, then user-id; clean-config and projects-gds were
  missing), exit codes lost behind `tee` (now `run_step.sh`), GDS compressed twice with `xz -9e` (now once, `-6`), a vague pad
  check (now `pad_abutment_check.tcl`), and "No chat log" (the user asked for one: `chatlog_tools/session_chatlog.sh`).
- Logs leave the container: `push_logs.sh` (append-only commits to branch `chipalooza_logs` of the fork), `push_logs_loop.sh` every
  120 s, `run_step.sh` after each step; GDS chunks go to `chipalooza_artifacts` (one force-pushed parentless commit). The session
  tests push access to both branches before any long step. Pusher overhead: about 1 s per push on a local repo with a 6.7 MB log,
  0.01 s when nothing changed; not measured against GitHub.
- Pad views: in this container (PDK e7a6777 by ciel) all 17 `gf180mcu_ocd_io__*` cells give an abutment box on the first call
  (`pad_abutment_check.tcl`). The installed `gf180mcuD.magicrc` lists `gf180mcu_fd_io` before `gf180mcu_ocd_io` and `gf180mcu_as_sc_mcu7t3v3`
  before `gf180mcu_ocd_io` (Belal's advice: those two at the top); its effect on the harness is untested.
- Session settings of the launch (from the user's screenshot): environment gf180mcuD, repository tatzelbrumm/gf180mcu_ocd_chipalooza,
  branch main, Sonnet 5.5, effort Medium, mode Auto. The user pasted the prompt and launched it at about 00:30 UTC. Whether the
  session can push to the fork was unknown at that time (its first step tests it).
- The chat log tools now find the last record that has a `uuid` themselves and handle user messages with images.

## Update 2026-11-23 ~01:10 UTC: first cloud build (summary by the assistant, from the session's REPORT.md and logs)
Logs: `../logs/main/chipalooza_cloud_20261123T0029Z/`; its chat log: `../chatlog/2026-11-23_sonnet_chipalooza_cloud_build.md`.
- `make setup` fails: `scripts/setup.sh` does not exist in the harness repo (Makefile target dead). The prompt now initialises the
  three submodules instead (they are empty in a fresh clone).
- Pad check passes (17 pads, 0 empty). Steps check ... gds-final, extract-sch-top, extract-top finished (extract-top 1621 s).
- **Exit codes are not evidence:** the harness scripts end with `exit 0`. `drc-final` logged `Cell name gf180mcu_ocd_chipalooza_final
  not found` (no .lyrdb), `lvs-top` logged `No file ../netlist/schematic/gf180mcu_ocd.io.spice` (no comp.out), both with rc=0.
- Cause of the drc-final failure according to the session: upstream commit `bf1d19b` replaced the Magic compositor with `fill_all.rb`,
  which keeps the top cell name, so `gds-final` no longer renames it. The session wrote a patch, `ISSUE.md` and `PR.md` into
  `fixes/` of branch `chipalooza_artifacts` of the fork (not applied to any build). Not verified by me.
- Sizes: final GDS (gz) 33.1 MB, xz pack 23.7 MB in one 90 MB chunk, prefill GDS 22.8 MB. So the full GDS fits in one chunk.
- The session also pushed `mag_files.tar.xz`, `gds_prefill_and_slots.tar` and `fixes/` to the artifacts branch, which the prompt's push
  permission (GDS chunks and cells.tsv only) did not cover.

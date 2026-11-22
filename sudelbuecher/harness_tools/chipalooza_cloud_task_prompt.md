<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# Cloud task: build the GF180 Chipalooza harness end to end

Written by the assistant, 2026-11-22. Paste the whole file `chipalooza_cloud_task_prompt.txt` (the same text as the block below, nothing else in it) as the first message of a Claude Code cloud session in the
**gf180mcuD** environment whose source repository is the fork `tatzelbrumm/gf180mcu_ocd_chipalooza`, **branch `main`**
(`78edf00` = upstream `d5ad122` plus a merge; the fork's `minesweeping` branch carries regenerated outputs and modified
run scripts, so it is not the branch for testing Tim's and Belal's fixes). Model: Sonnet 5.5 for the run; for a failing
step start a second session (Opus 5.5) with that step's log. Paste the block as it is; the push permission is part of it. The session needs network access to github.com only (already allowed).

```
Goal: build the Chipalooza harness (README steps 4-13) in this environment and bring the complete final GDS to the user.
Do not debug at length: on the first failing step stop and report it.

Bootstrap (this session has only the harness checkout; the tools and notes live on the orphan branch sudel_buecher of
claude-cloud-config, public, read anonymously):
  git clone --depth 1 -b sudel_buecher https://github.com/tatzelbrumm/claude-cloud-config /var/tmp/sb
  SB=/var/tmp/sb/sudelbuecher        # all "$SB/..." paths below
  mkdir -p /var/tmp/runs

PUSH PERMISSION (given by the user with this message; nothing else may be pushed, ever):
PUSH_URL=https://github.com/tatzelbrumm/gf180mcu_ocd_chipalooza
LOGS_BRANCH=chipalooza_logs   (normal commits, append only, logs and the report)
ART_BRANCH=chipalooza_artifacts   (one parentless commit, force-pushed, GDS chunks and cells.tsv only)
No other branch, no other repo, no tags, no changes to main. Logs are pushed from the start and after every step, so
that nothing depends on this container surviving.

Rules: the harness checkout's working tree stays clean. Write every log to /var/tmp/runs/<step>.log (tee), print only
its tail, never cat a whole log. Run each long step with nohup in the background and poll the log; the container can be
reclaimed when idle. Do not edit harness scripts, do not source .designinit (it is for the user's local container),
do not run `make synth-hk` or `make synth-ctrl` (they need LibreLane under nix; the digital layouts are committed as .mag).

0a. Push test, before anything long: echo "start $(date -u)" > /var/tmp/runs/00_start.log, then
   $SB/harness_tools/push_logs.sh $PUSH_URL $LOGS_BRANCH /var/tmp/runs "start". If it prints PUSH_LOGS_FAILED, stop and
   report the error text: the user would rather fix access now than lose hours of logs.
0. Environment. Print: `tail -3 /foss/setup.log`, `grep -c PDK_LIB_MISSING /foss/setup.log` (expect 0),
   `echo $PDK_ROOT $PDK`, `magic --version`, `ls $PDK_ROOT/$PDK/libs.ref`, `nproc; free -g; df -h /var/tmp`.
   Also state which model you are running as, and your effort setting if you can see it (use your get_session tool if you
   have one; otherwise say you cannot tell). The user chose these in the start screen, or got the defaults, and wants to know.
   Expect /foss/pdks gf180mcuD, Magic 8.3.706, libraries incl. gf180mcu_ocd_io and gf180mcu_as_sc_mcu7t3v3.
   If the setup log shows PDK_FAILED, stop and say so.
1. Pad views. Read $SB/notes/2026-11-19_gf180_harness_handoff.md (section
   "What the toolchain needs", items 1 and "Pad library views"). After `make setup`, check the abutment box of all 17 pads
   in one Magic session (first `instance list abutment <name>` after `getcell` must not be empty). Report the addpath order
   of gf180mcuD.magicrc (is gf180mcu_ocd_io before gf180mcu_fd_io?). Do not change anything.
2. After EVERY step (success or failure) run $SB/harness_tools/push_logs.sh $PUSH_URL $LOGS_BRANCH /var/tmp/runs "<step>".
   A push failure is reported but does not stop the build.
   In this order, one step at a time, with duration and exit code each, stopping at the first failure:
   make check; make setup; make config; make padframe; make user-id; make wrappers; make symbols; make gds-slots;
   make gds-prefill; make drc; make gds-final; make drc-final; make extract-sch-top; make extract-top; make lvs-top.
   (README says top-level LVS currently fails on the 5 V / 3 V ground domains: report the failure, do not fix it.)
   `make config` refuses to overwrite: run `make clean-config` first if it says so.
3. Evidence. For the final GDS run: python3 $SB/harness_tools/cell_hashes.py <final gds> /var/tmp/runs/cells.tsv
   (pip klayout is installed). Also keep the .lyrdb summaries and the netgen comp.out files.
4. Packaging. Measure first: `xz -9e -T0 -c <final gds> | wc -c`. Then
   $SB/harness_tools/gds_pack.sh <final gds> /var/tmp/pack 90M
   Then push the chunks: PUSH_URL=$PUSH_URL PUSH_BRANCH=$ART_BRANCH $SB/harness_tools/gds_pack.sh <final gds> /var/tmp/pack 90M
   (run gds_pack.sh once, with these variables set; it force-pushes /var/tmp/pack as one commit). Also copy cells.tsv into
   /var/tmp/runs and push the logs again.
5. Report: one table (step, exit code, seconds, first error), the sizes (final GDS, packed, chunks), the pad-view findings
   of step 1, the path of each log and of cells.tsv. Push the report as /var/tmp/runs/REPORT.md with the last push_logs.sh call, so it
   is on $LOGS_BRANCH too. Do not push or commit anything except what PUSH PERMISSION allows. No chat log.
```

Afterwards, locally: `git fetch tatzelfork chipalooza_logs chipalooza_artifacts` (logs: `git log tatzelfork/chipalooza_logs`, files under run-<time>/), then `git fetch --depth 1 tatzelfork chipalooza_artifacts`, `sudelbuecher/harness_tools/gds_unpack.sh <dir> <out>`,
`python3 sudelbuecher/harness_tools/cell_hashes.py <out>/<name> mine.tsv`, and compare the tables (README of harness_tools).

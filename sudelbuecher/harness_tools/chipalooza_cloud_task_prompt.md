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
On a failing step: find the cause from the log, prepare a fix as a patch file in the repository, and report; apply it and rerun
only when the user says so.

BOOTSTRAP (first command; the tools and notes live on the public orphan branch sudel_buecher of claude-cloud-config):
  git clone --depth 1 -b sudel_buecher https://github.com/tatzelbrumm/claude-cloud-config /var/tmp/sb && mkdir -p /var/tmp/runs
  cat > /var/tmp/env.sh <<'X'
  export SB=/var/tmp/sb/sudelbuecher PUSH_URL=https://github.com/tatzelbrumm/gf180mcu_ocd_chipalooza
  export LOGS_BRANCH=chipalooza_logs ART_BRANCH=chipalooza_artifacts
  X
Every Bash call starts a fresh shell: begin each command that uses $SB, $PUSH_URL, $LOGS_BRANCH or $ART_BRANCH with
`. /var/tmp/env.sh`. The harness checkout is this session's repository (cd into it; `git rev-parse --show-toplevel`).

PUSH PERMISSION (given by the user with this message). Everything the user wants out of this container goes into the user's own
repository $PUSH_URL, nothing anywhere else:
  - branch $LOGS_BRANCH: normal commits, append only: logs, chat log, report.
  - branch $ART_BRANCH: force-pushed (replace) any time: packed GDS (chunks of at most 90 MB), cells.tsv, a compressed tarball
    (xz, chunks) of the WHOLE working tree including ignored and untracked files (not .git) at the end of the run, patches,
    ISSUE.md / PR.md drafts and any other file the user may want to read. Put patches and drafts where the user can see their
    contents as plain files (e.g. fixes/), not only inside a tarball.
  - the session's own claude/* branch: the stop hook may ask you to commit there; you may, if the user has no objection.
  - never: main, tags, any other repo, a pull request or an issue (prepare the files; the user files them), the raw session
    transcript (it holds reasoning; the built chat log is the record).
  Logs go to the repository from the start and during every step, so nothing depends on this container surviving.

RULES: build outputs in the working tree are expected (the build rewrites tracked files). Do not hand-edit tracked files, with
this exception: a patch you prepared may be applied to the working tree to rerun a step when the user says so; keep the patch
file visible in the repository. Do not source .designinit (it is for the user's local container). Do not run
`make synth-hk` or `make synth-ctrl` (they need LibreLane under nix; the digital layouts are committed as .mag). Each step
below runs through the step runner, from the harness checkout, in the background, and is polled:
  . /var/tmp/env.sh; nohup $SB/harness_tools/run_step.sh <name> make <target> > /dev/null 2>&1 &
  until grep -q '^END' /var/tmp/runs/<name>.status; do sleep 15; done; cat /var/tmp/runs/<name>.status; tail -5 /var/tmp/runs/<name>.log
(repeat the `until` line if the tool call times out; never cat a whole log). The runner writes the log, the real exit code
and the seconds, and pushes the logs when the step ends.

0a. PUSH TEST, before anything long. All three must succeed, else stop and report the exact error (no long step without push access):
  . /var/tmp/env.sh; echo "start $(date -u)" > /var/tmp/runs/00_start.log; $SB/harness_tools/push_logs.sh $PUSH_URL $LOGS_BRANCH /var/tmp/runs start
  echo test > /var/tmp/ptest.txt; PUSH_URL=$PUSH_URL PUSH_BRANCH=$ART_BRANCH $SB/harness_tools/gds_pack.sh /var/tmp/ptest.txt /var/tmp/ptest_pack 1M
  git ls-remote $PUSH_URL $LOGS_BRANCH $ART_BRANCH        (both branches must be listed)
  Then start the background pusher (every log in the repository within two minutes, also during a step of hours):
  . /var/tmp/env.sh; nohup $SB/harness_tools/push_logs_loop.sh $PUSH_URL $LOGS_BRANCH /var/tmp/runs 120 > /var/tmp/push_loop.log 2>&1 &
  then `pgrep -f push_logs_loop` must show it.
  CHAT LOG (the user explicitly asks for one): after every step and at the end run
  . /var/tmp/env.sh; $SB/chatlog_tools/session_chatlog.sh /var/tmp/runs/chatlog.md "Chipalooza cloud build" "<your model>"
  (counts only; the pusher pushes it). Exit 2 NO_TRANSCRIPT: say so, never reconstruct a log. Exit 1: report it.

0. ENVIRONMENT. Print: `tail -3 /foss/setup.log`, `grep -c PDK_LIB_MISSING /foss/setup.log` (expect 0), `echo $PDK_ROOT $PDK`,
  `magic --version`, `ls $PDK_ROOT/$PDK/libs.ref`, `nproc; free -g; df -h /var/tmp`. Expect /foss/pdks gf180mcuD, Magic 8.3.706,
  libraries incl. gf180mcu_ocd_io and gf180mcu_as_sc_mcu7t3v3. State which model you run as and your effort setting if you
  can see it (get_session tool if you have one; else say you cannot tell). If the setup log shows PDK_FAILED, stop and say so.

1. CHECK, SUBMODULES AND PAD VIEWS. Run the step `check` (make check; a fresh clone prints "0 stale, 1 not built": validate/lvs/comp.out,
  that is fine). `make setup` is NOT used: scripts/setup.sh, which it calls, does not exist in the repo. Instead run the step
  `submodules` (git submodule update --init --depth 1): README step 1 needs the three dependencies/ repositories
  (public, pinned commits), and a fresh clone has them empty. Then, in the harness checkout:
  . /var/tmp/env.sh; magic -dnull -noconsole -rcfile $PDK_ROOT/$PDK/libs.tech/magic/$PDK.magicrc $SB/harness_tools/pad_abutment_check.tcl 2>&1 | grep ABUT
  Expect `ABUT_SUMMARY pads 17 empty 0` (this passed in the user's environment build on 2026-11-23). An empty box means stale pad views:
  read $SB/notes/2026-11-19_gf180_harness_handoff.md (bullet "Pad library views") and report; do not fix.
  Also report `grep -n addpath $PDK_ROOT/$PDK/libs.tech/magic/gf180mcuD.magicrc` (Belal's advice: gf180mcu_ocd_io and
  gf180mcu_as_sc_mcu7t3v3 at the top; the installed file lists gf180mcu_fd_io before ocd_io). Change nothing.

2. BUILD, README order, one step at a time (step name = make target), stop at the first failure except where noted:
  clean-config (README 4: saves the previous generated files to archive/), config, padframe, wrappers, symbols, gds-slots,
  user-id, projects-gds (all 18 slots are "-": if it fails for lack of projects, report and CONTINUE), gds-prefill, gds-final,
  drc-final, extract-sch-top, extract-top, lvs-top. BEFORE lvs-top, copy the pad netlist the LVS script reads (it is in no commit):
  cp $PDK_ROOT/$PDK/libs.ref/gf180mcu_ocd_io/spice/gf180mcu_ocd_io.spice netlist/schematic/   (untracked input; never commit it).
  The harness scripts exit 0 whatever happens: judge DRC/extract/LVS steps by their log (grep ERROR) and output files, not by rc.
  (README says top-level LVS currently fails on the 5 V / 3 V ground domains:
  report the failure, do not fix it). If a step refuses because a file exists (config, padframe), say which file; do not delete it.

3. FINAL GDS. Find it: `ls -la gds magic | grep -i final` (expect gds/gf180mcu_ocd_chipalooza_final.gds, maybe .gz). Estimate:
  `head -c 200000000 <final gds> | xz -6 -T0 | wc -c`. Then pack and push (xz -6, chunks of 90 MB; runs once; for a .gz file the
  packing gains little, report the sizes):
  . /var/tmp/env.sh; PUSH_URL=$PUSH_URL PUSH_BRANCH=$ART_BRANCH $SB/harness_tools/gds_pack.sh <final gds> /var/tmp/pack 90M
  Only after that, in the background with a time limit (needs RAM for the whole layout; may time out, report that):
  timeout 3600 python3 $SB/harness_tools/cell_hashes.py <final gds> /var/tmp/runs/cells.tsv
  Keep the .lyrdb summaries and the netgen comp.out files in /var/tmp/runs too (copy them there; they are small).

4. REPORT. One table (step, exit code, seconds, first error), the sizes (final GDS, packed, chunks), the pad-view findings of
  step 1, the model and effort. Write it to /var/tmp/runs/REPORT.md, rebuild the chat log, and run the push once more:
  . /var/tmp/env.sh; $SB/harness_tools/push_logs.sh $PUSH_URL $LOGS_BRANCH /var/tmp/runs final
```

Afterwards, locally: `git fetch tatzelfork chipalooza_logs chipalooza_artifacts` (logs: `git log tatzelfork/chipalooza_logs`, files under run-<time>/), then `git fetch --depth 1 tatzelfork chipalooza_artifacts`, `sudelbuecher/harness_tools/gds_unpack.sh <dir> <out>`,
`python3 sudelbuecher/harness_tools/cell_hashes.py <out>/<name> mine.tsv`, and compare the tables (README of harness_tools).

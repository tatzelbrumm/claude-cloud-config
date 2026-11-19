<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# Hand-off, 2026-11-19: gf180mcuD environment that can build the Chipalooza harness

**This is a summary written by the assistant. It is not a chat log and not verbatim.** Session: claude.ai Project
"chipalooza gf180", cloud session `session_01XU3KH5axhpi3C2PpQsrPoE` (Sonnet 5.5 until 2026-11-19 01:24 Berlin, then
Opus 5.5). It continues `2026-11-13_multi_pdk_cloud_setup.md`. Written for the Claude Code session that takes over the
gf180mcuD part of `claude-cloud-config` (branch `multi-pdk`, parts in `parts/`, generated scripts by `./make-setup.sh all`).

## Goal

A cloud environment, set up by `setup-gf180mcuD.sh`, in which the GF180 Chipalooza harness
(`tatzelbrumm/gf180mcu_ocd_chipalooza`, a fork of `RTimothyEdwards/gf180mcu_ocd_chipalooza`) builds end to end:
`make padframe`, wrappers, GDS, LVS. The user must build the harness, and wants Magic's version and configuration problems
kept inside this environment, not on his machine.

## What the toolchain needs (findings, with sources)

1. **PDK.** Belal Shinnawey (FOSSi), 2026-11-19, built the chip end to end with
   `ciel enable --pdk gf180mcu e7a6777d157a9d94c7ac757457b9e4309e9e9000 -l all` and "the latest magic". Release page:
   `https://github.com/fossi-foundation/ciel-releases/releases/tag/gf180mcu-e7a6777d157a9d94c7ac757457b9e4309e9e9000`.
   `e7a6777` is the open_pdks commit "Merge pull request #576 … fix_cdl_spice_annotate", 2026-11-12. He also says to
   put the `gf180mcu_ocd_io` and `gf180mcu_as_sc_mcu7t3v3` paths at the **top** of `gf180mcuD/libs.tech/magic/gf180mcuD.magicrc`
   when building the padframe. In the e7a6777 source magicrc they are already present, but after the `gf180mcu_fd_*`
   libraries (`gf180mcu/magic/gf180mcu.magicrc` lines 48–56). Why the order matters is not verified (guess: cells of the
   same name in `gf180mcu_fd_io`).
2. **Magic ≥ 8.3.693.** The e7a6777 tech file says `requires magic-8.3.693`; Magic 8.3.685 (IIC-OSIC-TOOLS 2026.10) refuses
   to load it (tested). Note: `gf180mcu.json` of e7a6777 still lists `reference.magic = d157eea` (8.3.637); the tech file's
   requirement is the one that is enforced. Magic 8.3.693 = commit `9fd4ee5` (2026-11-03) of `RTimothyEdwards/magic`;
   current master was 8.3.703/8.3.704 on 2026-11-19.
   Magic 8.3.691 (`6f32dde`) makes timestamps of cells read from GDS a hash of the GDS data, so they no longer change with
   every PDK install. That is the likely reason the newer Magic matters for the harness (its own `.mag` cells record
   timestamps of PDK cells); reasoning, not tested.
3. **IIC-OSIC-TOOLS has not caught up.** `iic-jku/iic-osic-tools` main at `f15ef6a` (2026-11-12) still pins
   `MAGIC_REPO_COMMIT="8.3.685"` and `OPEN_PDKS_REPO_COMMIT=1689ac3…`. So the pinned versions in `parts/` cannot simply be
   copied from a newer IIC release; this environment has to build Magic itself.

## Tested in this session's sandbox (Ubuntu 24.04)

- **Building Magic 8.3.693:** `apt-get install tcl-dev tk-dev csh libglu1-mesa-dev` (libcairo2-dev, libx11-dev,
  libncurses-dev, m4 were already present), then from `git archive 9fd4ee5`:
  `./configure --prefix=<own dir> && make -j8 && make install`: 19 s, `magic --version` = 8.3.693. IIC builds it the same
  way, plus `make database/database.h` before `make` (`_build/images/magic/scripts/install.sh`). Install into its own
  prefix and put it first on `PATH`; do not replace the 8.3.685 of the tools archive unless the rest is checked.
- **Tech file without ciel:** `open_pdks` is reachable by `git clone` (the git proxy serves public GitHub) while
  `fossi-foundation.github.io` is refused (HTTP 403 on CONNECT, `recentRelayFailures` in
  `curl -sS "$HTTPS_PROXY/__agentproxy/status"`). The gf180mcuD Magic tech can be built from the source tree:
  `python3 common/preproc.py -DTECHNAME=gf180mcuD -DREVISION=<rev> -DMETALS5 -DMIM -DTHICKMET1P1 -DHRPOLY1K
  gf180mcu/magic/gf180mcu.tech <out>/gf180mcuD.tech`, the same for `gf180mcu-{cifout,cifin,drc,extract}.tech` and
  `gf180mcugds.tech` (→ `gf180mcuD-GDS.tech`); defines from `gf180mcu/Makefile.in` (`GF180MCUD_DEFS`). Built from 1689ac3 it
  loads in 8.3.685; built from e7a6777 it loads in 8.3.693 (133 layers each). That is only the Magic tech, not a PDK.
- **Pad library views:** open_pdks builds `gf180mcu_ocd_io` from GDS (`Makefile.in` target `ocd-io-%`:
  `-gds cells/*/*_5lm.gds.gz`, options `custom/scripts/gds_import_io.tcl` = `gds flatglob *_CDNS_*`), not from the pad
  repo's `magic/` folder. The repo's hand-saved `magic/` views have stale child timestamps, and with them the first
  `instance list abutment <name>` after `getcell` returns an empty string (still so in 8.3.693, tested), which broke
  `make padframe`. Importing all 17 `*_5lm.gds.gz` in **one** Magic session (`gds noduplicates true`, then
  `writeall force`) gives 107 cells, 0 timestamp mismatches, and the abutment box of every pad on the first call (8.3.685
  and 8.3.693). A ciel-installed PDK should already have such views; that is not verified, since ciel could not be reached.

## Work for the Claude Code session

1. **Network.** In the cloud environment for gf180mcuD: Network access → Custom → Allowed domains, add
   `fossi-foundation.github.io`, then whatever further host `recentRelayFailures` names after a failing `ciel enable`
   (the release tarballs are GitHub release assets; their download host was not observed). Changes apply to new sessions.
2. **`parts/pdk-gf180mcuD.sh`:** pin `OPEN_PDKS_COMMIT=e7a6777d157a9d94c7ac757457b9e4309e9e9000` and fetch all libraries
   (Belal: `-l all`; check how the current `ciel` spells it next to `--pdk-family gf180mcu`). Keep the IIC fixes that still
   apply. Add the magicrc reordering (ocd_io, as_sc first) as a guarded `sed`, and report the resulting `addpath` order.
3. **New part for Magic** (or a block in `main.sh`): build `MAGIC_COMMIT=${MAGIC_COMMIT:-9fd4ee5}` (8.3.693) into
   `$F/tools/magic-<version>`, in the background like the PDK, with its log; install the four apt packages first; fail
   loudly (`MAGIC_FAILED`) and leave 8.3.685 in place if the build fails. Decide with the user whether to default to
   8.3.693 or a newer master.
4. **Fallback when ciel is unreachable** (optional): the git-only route above, for the tech file and the cell libraries
   (pins in e7a6777 `gf180mcu/gf180mcu.json`, `reference`: e.g. `gf180mcu_ocd_io` 6e0e354, `gf180mcu_as_sc_mcu7t3v3` aa30990,
   `gf180mcu_ocd_alpha` 0597ebd, `gf180mcu_ocd_ip_sram` d41c744).
5. **Test** in a real session of that environment: `setup-gf180mcuD.sh`, then `magic --version`, load the tech, and the
   abutment test on all 17 pads. Then, with the harness fork cloned, `make check-timestamps` and `make padframe`.
6. Edit only `parts/`, regenerate with `./make-setup.sh all`, commit parts and generated scripts together (`CLAUDE.md`).

## Where the related work is (user's machine, not all of it on GitHub)

- Harness fork, branch `minesweeping` (local `~/EDA/gf180mcu_ocd_chipalooza`), **uncommitted** as of 2026-11-19:
  `scripts/check_timestamps.py` (static check of recorded vs. actual child timestamps, Magic's rule from
  `database/DBio.c`), `scripts/resave_stale_parents.sh` (re-saves stale parents with Magic, keeps `$PDKPATH` paths),
  Makefile targets `check-timestamps` and `resave-stale`. A cloud session sees them only after the user commits and pushes.
- `~/EDA/gf180_cm_ip__single2diff2single_sudelbuecher/_runs/make_pdk_overlay.sh`: overlay PDK for the IIC container
  (links to `/foss/pdks/gf180mcuD` plus the missing libraries; since 2026-11-19 it generates the ocd_io views from GDS).
  It is the stopgap for the local container, not the cloud route.
- Running log of this stretch: `gf180_cm_ip__single2diff2single`, branch `sudel_buecher`,
  `sudelbuecher/logs/main/2026-11-19_opus_padframe_minesweeping_log.md`.

## Not decided

- Default Magic version (8.3.693 minimum vs. current master).
- Whether to drop Magic from parts of the harness flow. Assessment given to the user on 2026-11-19: a full purge is a
  rewrite (51 `.mag` cells, ~2,600 lines of Magic Tcl, extraction for LVS); the user's direction so far is to contain
  Magic in this environment rather than purge it.

## Prompt for the session (paste as the first message)

> Read `CLAUDE.md` and, in the `sudel_buecher` worktree, `sudelbuecher/notes/2026-11-19_gf180_harness_handoff.md` and
> `2026-11-13_multi_pdk_cloud_setup.md`. Then do "Work for the Claude Code session" items 2, 3 and 5 on branch `multi-pdk`:
> PDK e7a6777 with all libraries, Magic 8.3.693 built into its own prefix, magicrc order fixed, tested in this session.
> Report every host the proxy refuses. Ask before changing the default Magic version or anything outside `parts/`.

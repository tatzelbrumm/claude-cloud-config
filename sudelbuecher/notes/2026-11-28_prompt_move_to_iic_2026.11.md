<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# Draft prompt: move claude-cloud-config to IIC-OSIC-TOOLS 2026.11 and add ihp-sg13g2

A draft for a new Claude Code session, written on 2026-11-28 in the session that adapted the ESD testbenches of
`tatzelbrumm/ihp-sg13g2-io` to 2026.11 (notes on that repository's `sudel_buecher` branch,
`sudelbuecher/notes/2026-11-27_io_pad_port_order_esd_models_iic_2026.11.md`). Fill in the branch and check the
`[CHANGE IF YOU DISAGREE]` decisions before using it. Everything below the line is the prompt.

---

Move tatzelbrumm/claude-cloud-config from the IIC-OSIC-TOOLS 2026.10 pins to 2026.11, and add an ihp-sg13g2
environment (the full SG13G2 process next to the restricted sg13cmos5l). Read CLAUDE.md and README.md first; the
rules there apply (edit parts/, run ./make-setup.sh all, commit parts and generated scripts together; record on
sudel_buecher, never a chat log unless I ask).

## Decisions (already made)

- No parallel support of two versions. Before changing anything, tag the current main as `iic-2026.10` and push the
  tag. Anyone who needs 2026.10 sets REV=iic-2026.10 in the generated script's header. Say so in the README.
- Pins = IIC-OSIC-TOOLS tag 2026.11 (github.com/iic-jku/IIC-OSIC-TOOLS, commit cb0b8b87). Read them from that tag,
  `_build/images/*/Dockerfile` and `_build/docker-bake.hcl`; don't take this list as the source. Known so far:
  xschem f36d748b, magic 8.3.706, netgen 1.5.332, ngspice-47 (unchanged), OpenVAF aec93673, KLayout 0.30.14,
  klayout-pex 0.11.1, CACE 2.13.0, Xyce Release-7.10.0 with Trilinos trilinos-release-12-12-1.
- IHP PDK: iic-jku/IHP-Open-PDK at 63b8b4c493f8822b3fd3c1797a21e2768e7a1ad5 (the head of dev when 2026.11 was built,
  2026-11-23), for both ihp-sg13cmos5l and the new ihp-sg13g2. Its libs.tech/verilog-a is unchanged since df4c5054,
  but recompile the OSDI models with the new OpenVAF.
- sky130A and gf180mcuD: the PDK versions of 2026.11 (read from the tag). [CHANGE IF YOU DISAGREE]
- Xyce goes in, as its own archive next to the tool archive (GitHub refuses files over 100 MB). Build it like
  `_build/images/xyce/scripts/install.sh` of the tag (MPI, the serial user_plugin step included), with ADMS from
  `_build/images/base/scripts/72_install_adms.sh`. A tested script that does exactly this, plugins included, is
  `recipe/build-xyce.sh` (branch `claude/friendly-heisenberg-jf99v2` until merged): about 25 min on 4 cores. The ihp-sg13g2 setup builds the PDK's Xyce plugins
  (Xyce_Plugin_PSP103_VA.so, Xyce_Plugin_r3_cmc.so) with `libs.tech/verilog-a/adms-compile-va.sh`, or ships them
  prebuilt if building them breaks the five-minute limit. [CHANGE IF YOU DISAGREE]
- The new environment: parts/pdk-ihp-sg13g2.sh, script setup-ihp-sg13g2.sh, environment variables PDK_ROOT=/foss/pdks,
  PDK=ihp-sg13g2, PDKPATH=/foss/pdks/ihp-sg13g2, STD_CELL_LIBRARY=sg13g2_stdcell. Sparse checkout of what analog and
  IO work needs: libs.tech/{xschem,ngspice,xyce,verilog-a,klayout,magic,netgen}, libs.ref/{sg13g2_io,sg13g2_stdcell,
  sg13g2_pr} with their sch/sym/spice views; leave out SRAM and other large libs.ref unless they fit the time budget.
  No digital variant for now.

## Constraints

- A setup script must finish in about five minutes or the environment isn't cached. It downloads and unpacks; it
  compiles nothing slow. If the new PDK or the plugins push it over, stop and tell me which part costs what.
- The tool archives are built once, in this session, with the recipe in recipe/ (extend it for Xyce). Every file in
  git under 100 MB.
- Keep tools/BUILDINFO and sources/ consistent with what's in the archives (source commits, compiler, date).

## Done when

1. Tag `iic-2026.10` pushed; main carries the 2026.11 pins.
2. Each generated setup script (setup-cloud.sh, setup-sky130A.sh, setup-gf180mcuD.sh, setup-ihp-sg13g2.sh) has run
   end to end in this container: `SETUP_DONE` with its time in /foss/setup.log, `PDK_DANGLING_LINKS` as expected,
   every `*_OK` step present. Where a PDK download is blocked by the network, say which host and leave it untested.
3. Smoke tests in the ihp-sg13g2 environment, each producing numbers, not just exit 0:
   - tatzelbrumm/ihp-sg13g2-io, master, xschem/esd_test_iopadanalog.sch and esd_test_iovdd.sch: netlist with xschem,
     run with ngspice and with Xyce. Reference (ngspice-47, PDK 63b8b4c4): peak discharge current −1.31 A, peak pad
     voltage 17.8 V (IOPadAnalog), peak iovdd 8.05 V and 1.90 V at 1.9 µs (IOPadIOVdd). Report the Xyce values next
     to these.
   - xschem opens a sheet of libs.ref/sg13g2_io/sch/xschem; magic loads the sg13g2 tech; the KLayout DRC deck runs
     on a real layout and its tables don't fail (an earlier run printed "Passed" while every table raised).
4. `./make-setup.sh all` leaves setup-cloud.sh changed only by the intended pin changes (show the diff).
5. README: the "Which script when" table gains ihp-sg13g2; the tool table shows the 2026.11 versions; tested and
   untested parts named honestly.
6. A note on sudel_buecher (notes/) with what was built, how long each setup took, and anything left open.

## Ask me before

- dropping any PDK or tool from the archives, or changing an environment variable name;
- anything that needs more than the package registries, github.com, www.klayout.org and the PDK download hosts.

Work on branch [your branch]; push there; no PR unless I ask.

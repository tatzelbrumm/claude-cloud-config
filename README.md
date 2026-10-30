<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# claude-cloud-config

A prebuilt open-source analog EDA toolchain, pinned to the **IIC-OSIC-TOOLS 2026.10** versions, and a setup
script for **Claude Code cloud sessions**. Made for Chipalooza 2026 designs in IHP **sg13cmos5l**, so that cloud
results come from the same tool versions as the IIC-OSIC-TOOLS container.

Why prebuilt: a Claude Code cloud environment is cached only if its setup script finishes in about five minutes.
Compiling ngspice alone takes almost that long, so a compiling setup script is never cached and gets cut off.
This setup script only downloads and unpacks.

## Use

Paste `setup-cloud.sh` into the cloud environment's **Setup script** (claude.ai/code: the caret after the
session title, then **Edit cloud environment**, then **Setup script**; save with **Save changes**). Network access:
the default package managers plus `www.klayout.org`. Environment variables: `PDK_ROOT=/foss/pdks`,
`PDK=ihp-sg13cmos5l`. In a session, `source .designinit` of a Chipalooza project sets the rest.

The script logs each step with its time in `/foss/setup.log` and ends with `SETUP_DONE <seconds>`.

## Which script when

| task | Setup script | extra |
|---|---|---|
| specification, schematic (Xschem, ngspice), layout, DRC/LVS/PEX | `setup-cloud.sh` | none |
| mixed-signal integration (Icarus, cocotb, Yosys, Verilator) | `setup-cloud.sh` + `setup-digital.sh` appended | none |

`setup-digital.sh` takes about 25 s (tested: Icarus 12.0, Yosys 0.33, Verilator 5.020, cocotb 2.1.0, distro versions, not the
IIC-OSIC-TOOLS pins). LibreLane/OpenROAD are not included: harden digital blocks in the local container.

Minimal-overhead session: paste the script(s) into the **Setup script** field of one environment per row above; select the
design repo (and only that repo) when starting the session. Public repos need no selection to be read, only to be pushed.

## Contents

| path | |
|---|---|
| `setup-cloud.sh` | the setup script |
| `tools/foss-tools-iic2026.10-ubuntu24.04-x86_64.tar.xz` | unpacks to `/foss/tools`: xschem, magic, netgen, ngspice, OpenVAF (`openvaf-r`), the IIC-OSIC-TOOLS `sak-*` scripts, and the IHP OSDI models compiled for one PDK commit |
| `tools/BUILDINFO` | the exact source commits, compiler, date (also inside the archive) |
| `sources/sources-iic2026.10.tar.xz` | the sources of those commits (`git archive`), plus OpenVAF's `Cargo.lock` after `cargo update` |
| `recipe/setup-build-from-source.sh` | the setup script that compiled them |

| tool | version |
|---|---|
| xschem | `d76e6cc7` (3.4.8RC) |
| magic | 8.3.685 |
| netgen | 1.5.324 |
| ngspice | ngspice-47 (`--enable-osdi --enable-xspice --enable-klu --enable-openmp`) |
| OpenVAF | `dd05b5e2` (`mb-experimental`, `openvaf-r`) |
| `sak-*` scripts | IIC-OSIC-TOOLS tag 2026.10 |
| KLayout, klayout-pex | 0.30.12, 0.6.8 (installed by the setup script, not in the archive) |
| IHP-Open-PDK (iic-jku fork) | `df4c5054` (cloned by the setup script; the archive's OSDI models match it) |

## Where it runs

The binaries are built for x86_64 Linux against Ubuntu 24.04's libraries and are installed at the fixed path
`/foss/tools` (the IIC-OSIC-TOOLS layout; the tools look for their own support files there). They run in Claude
Code cloud sessions, on GitHub Actions `ubuntu-24.04` runners and on Ubuntu 24.04 machines or containers. They
don't run on older distributions, macOS or ARM.

## Provenance

Built once in a Claude Code cloud session on 2026-10-30, with the recipe in `recipe/`. Not yet built by CI.

## Licenses

The scripts in this repository: Apache-2.0. The tools keep their own licenses: xschem GPL-2.0-or-later, netgen GPL-1.0,
OpenVAF GPL-3.0, magic (Regents of the University of California, permissive), ngspice (its `COPYING`), `sak-*`
scripts Apache-2.0. Their sources are in `sources/`.

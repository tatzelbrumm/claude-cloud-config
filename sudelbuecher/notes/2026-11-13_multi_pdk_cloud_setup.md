<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# Multi-PDK cloud setup, 2026-11-13: decisions and findings

**This is a summary written by the assistant. It is not a chat log and not verbatim.** Session: claude.ai Project
"chipalooza gf180", Claude Code cloud session `session_01XU3KH5axhpi3C2PpQsrPoE`, model Sonnet 5.5. The work is on
branch `multi-pdk` of `claude-cloud-config` (commit `ed7881d`).

## Decision

One repository for all three PDKs, not one per PDK, because:
- the tools archive (35 MB) and the sources (25 MB) are committed binaries, and the tool pins come from one
  IIC-OSIC-TOOLS release shared by all PDKs;
- only the PDK block, the OSDI step and the `kpex` wrapper of `setup-cloud.sh` are specific to ihp-sg13cmos5l.

Layout: `parts/` (`header.sh`, `pdk-<PDK>.sh`, `digital.sh`, `main.sh`) and `make-setup.sh`, which concatenates them in
that order into one pasteable script per PDK. `setup-cloud.sh` keeps its name for ihp-sg13cmos5l.

## Findings

- IIC-OSIC-TOOLS 2026.10 installs sky130A and gf180mcuD with `ciel enable <open_pdks commit> --pdk[-family] ...`
  (commit `1689ac3f2dc763876eaf967227c7dfe831b031ae`, `_build/images/open_pdks/Dockerfile`), then patches. ihp-sg13cmos5l is
  installed separately (`install_ihp.sh`, `install_ihp_cmos5l.sh`, which states that CMOS5L symlinks into SG13G2).
- In the iic-jku IHP fork at `df4c5054`, `ihp-sg13cmos5l/libs.ref/sg13cmos5l_sram` links to `ihp-sg13g2/libs.ref/sg13g2_sram`
  (44 MB) and the 84 `sch/xschem/*.sch` files of `sg13cmos5l_stdcell` link into `ihp-sg13g2/libs.ref/sg13g2_stdcell/sch`
  (1.2 MB). The IO pad library `sg13cmos5l_io` is real files. The old sparse checkout had none of the link targets, so those
  links dangled in the cloud (331 dangling links in all, 222 of them in `libs.tech/gnucap`, 20 in `libs.tech/xyce`, which the
  flow does not use). Fixed: `sg13g2_stdcell/sch` is checked out; `WITH_SRAM=1` adds the sram.
- The old two-file digital recipe (`setup-cloud.sh` + `setup-digital.sh` appended) cannot work in one pasted script:
  `setup-cloud.sh` ends with `exit 0`.
- In the sandbox of this session the proxy refused `fossi-foundation.github.io` (ciel's release index, HTTP 403 on
  CONNECT), so the sky130A and gf180mcuD scripts are **untested against the real download**. `setup-cloud.sh` was run end to
  end (32 s; `KLAYOUT_DEB_FAILED` because klayout.org was blocked too). The log is `../logs/multi-pdk/setup-cloud_2026-11-13.log`.
- The cloud container of this session has no raw transcript, so no verbatim chat log could be made (see `../chatlog/README.md`).

## Open

- Run `setup-sky130A.sh` and `setup-gf180mcuD.sh` in real cloud environments (allow the hosts ciel downloads from) and read
  the times in `/foss/setup.log`; use `CIEL_LIB_OPTS` if the five-minute limit is hit.
- gf180mcuD: variant D only; the PyCell patches (gdsfactory 9.x, efuse) and the Liberty gzip of IIC-OSIC-TOOLS are not ported.
- Merge `multi-pdk` into `main` when the above is checked.

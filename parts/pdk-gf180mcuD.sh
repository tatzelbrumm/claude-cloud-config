# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- PDK: gf180mcuD (GlobalFoundries 180 nm MCU, variant D; open_pdks build installed with ciel), plus Magic built
# from source, because the Chipalooza #3 harness needs a newer PDK and Magic than IIC-OSIC-TOOLS 2026.10 ships ----
# Defines PDK_NAME, pdk_fetch (runs in the background, in parallel with the tools) and pdk_post (runs after `wait`).
#
# Why not the IIC-OSIC-TOOLS 2026.10 pins (open_pdks 1689ac3, Magic 8.3.685), found 2026-11-19 on the harness
# github.com/RTimothyEdwards/gf180mcu_ocd_chipalooza:
#  - PDK e7a6777 (open_pdks 2026-11-12) is the one the harness was built with end to end (Belal El-Shinnawey,
#    FOSSi, 2026-11-19: `ciel enable --pdk gf180mcu e7a6777d157a9d94c7ac757457b9e4309e9e9000 -l all`). It has
#    gf180mcu_ocd_io, gf180mcu_ocd_alpha_*, gf180mcu_ocd_ip_sram, gf180mcu_as_sc_mcu7t3v3; 1689ac3 lacks the pad library.
#  - its Magic tech file says `requires magic-8.3.693`; 8.3.685 refuses to load it.
#  - Magic 8.3.705 (tag 8.3.705 = cc0360b) has two fixes the harness needs: `is_locked` initialized (1a6e9e5; with
#    `locking disable` every cell read from disk was "not writeable"), and GDS_FILE resolved relative to the cell
#    (8.3.690 eeb1052; `make gds-prefill` lost the seal ring and the top cell). Tested on the user's machine: padframe,
#    wrappers, symbols, gds-slots, user-id, gds-prefill all OK with 8.3.705 + e7a6777.
#
# Network: ciel reads its index from https://fossi-foundation.github.io/ciel-releases (not in the Trusted list: use
# Network access "Custom", check "Also include default list", add fossi-foundation.github.io). The tarballs are GitHub
# release assets (github.com, release-assets.githubusercontent.com: in the default list). If the index host is
# refused, pdk_fetch retries through the GitHub API data source (api.github.com, also in the default list).
# Environment variables for sessions: PDK_ROOT=/foss/pdks PDK=gf180mcuD PDKPATH=/foss/pdks/gf180mcuD
# GF_PDK_OPTION=D STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0
PDK_NAME=gf180mcuD
OPEN_PDKS_COMMIT=${OPEN_PDKS_COMMIT:-e7a6777d157a9d94c7ac757457b9e4309e9e9000}  # IIC-OSIC-TOOLS 2026.10 had 1689ac3f
# Libraries for `ciel enable`: all of them, as Belal did (the harness uses ocd_io, ocd_alpha_*, ocd_ip_sram, as_sc).
# On the user's machine: 1.1 GB for gf180mcuD. To fetch less: CIEL_LIB_OPTS="-l gf180mcu_fd_pr -l gf180mcu_ocd_io ..."
CIEL_LIB_OPTS=${CIEL_LIB_OPTS:--l all}
MAGIC_TAG=${MAGIC_TAG:-8.3.705}                       # git tag of github.com/RTimothyEdwards/magic

pdk_fetch() {
  pip install -q --break-system-packages --ignore-installed ciel || { echo "PDK_FAILED pip ciel"; return 1; }
  ciel enable --pdk-root $F/pdks --pdk-family gf180mcu $CIEL_LIB_OPTS $OPEN_PDKS_COMMIT \
    || { echo "PDK_RETRY via GitHub API (fossi-foundation.github.io refused?)"
         ciel enable --data-source github-releases:fossi-foundation/ciel-releases \
           --pdk-root $F/pdks --pdk-family gf180mcu $CIEL_LIB_OPTS $OPEN_PDKS_COMMIT; } \
    || { echo "PDK_FAILED ciel enable"; return 1; }
  # variants A, B and C are not wanted (IIC-OSIC-TOOLS removes them too). Keep C: remove `C` from the next two lines.
  rm -rf $F/pdks/ciel/gf180mcu/versions/*/gf180mcu{A,B,C}
  rm -rf $F/pdks/gf180mcu{A,B,C}
  D=$F/pdks/gf180mcuD
  [ -d $D ] || { echo "PDK_FAILED gf180mcuD not found after ciel enable"; return 1; }
  ok PDK
  # Fixes copied from IIC-OSIC-TOOLS 2026.10 (_build/images/open_pdks/scripts/install_ciel.sh), each guarded:
  [ -d $D/libs.tech/ngspice ] && touch $D/libs.tech/ngspice/.spiceinit          # empty .spiceinit (as for SG13G2)
  find $D/ -name testing -prune -exec rm -rf {} +                               # testing folders, to save space
  [ -f $D/libs.tech/xschem/tests/0_top.sch ] \
    && sed -i 's/{test_/{tests\/test_/g' $D/libs.tech/xschem/tests/0_top.sch     # test schematic relative paths
  # PDK variant missing in the path definition of xschemrc
  [ -f $D/libs.tech/xschem/xschemrc ] \
    && sed -i 's|set 180MCU_MODELS ${PDK_ROOT}/models/ngspice|set 180MCU_MODELS ${PDK_ROOT}/gf180mcuD/libs.tech/ngspice|' \
         $D/libs.tech/xschem/xschemrc
  # xschem menu entry "Create FET .save file" ran the shell command `mkdir -p` from Tcl: Tcl's `file mkdir` is equivalent
  M=$D/libs.tech/xschem/xschem-menu
  if [ -f $M ] && grep -q '^[[:space:]]*mkdir -p \$netlist_dir[[:space:]]*$' $M; then
    sed -i 's/^\([[:space:]]*\)mkdir -p \$netlist_dir[[:space:]]*$/\1file mkdir $netlist_dir/' $M
  else
    echo "xschem-menu: 'mkdir -p \$netlist_dir' not found (already fixed upstream?)"
  fi
  # the OP annotation of the xschem transistor symbols named a sky130 model; the element is m0 in gf180mcu subcircuits
  find $D/libs.tech/xschem -name '*.sym' -exec sed -i 's/msky130_fd_pr__@model/m0/g' {} +
  # KLayout macro directory must be writable (options, run directory)
  [ -d $D/libs.tech/klayout/tech/macros ] && chmod -R a+w $D/libs.tech/klayout/tech/macros
}

# Magic $MAGIC_TAG from source, into $F/tools/magic (where main.sh links it from); the archive's 8.3.685 is moved to
# $F/tools/magic-8.3.685 and put back if the build fails. Runs after `wait`, so apt is free. About 20 s with 8 CPUs.
magic_build() {
  local src=/tmp/magic-src old=$F/tools/magic-8.3.685
  apt-get install -y -qq --no-install-recommends build-essential m4 csh tcl-dev tk-dev libcairo2-dev libx11-dev \
      libncurses-dev libglu1-mesa-dev zlib1g-dev \
    && git -c advice.detachedHead=false clone -q --depth 1 --branch $MAGIC_TAG https://github.com/RTimothyEdwards/magic $src \
    || { echo "MAGIC_FAILED fetch (8.3.685 kept)"; return 1; }
  [ -d $F/tools/magic ] && [ ! -e $old ] && mv $F/tools/magic $old
  ( cd $src && ./configure -q --prefix=$F/tools/magic > /tmp/magic-configure.log 2>&1 \
      && make database/database.h > /dev/null && make -s -j"$(nproc)" > /tmp/magic-make.log 2>&1 \
      && make -s install > /tmp/magic-install.log 2>&1 ) \
    && [ "$($F/tools/magic/bin/magic --version 2>/dev/null)" = "$MAGIC_TAG" ] \
    || { echo "MAGIC_FAILED build (8.3.685 kept; logs /tmp/magic-*.log)"; tail -20 /tmp/magic-make.log
         rm -rf $F/tools/magic; [ -d $old ] && mv $old $F/tools/magic; return 1; }
  rm -rf $src
  ok MAGIC
  echo "MAGIC_VERSION $($F/tools/magic/bin/magic --version)"
}

pdk_post() {
  magic_build
  # not ported from IIC-OSIC-TOOLS: gzip of the Liberty files, and the two patches of the KLayout PyCells to
  # gdsfactory 9.x and the efuse PyCell (_build/images/open_pdks/patches/gf180mcu-*.patch). The PyCells need
  # gdsfactory in KLayout's Python; the GDS/LEF of the pad and standard cell libraries do not.
  echo "PDK_LIBS $PDK_NAME: $(ls $F/pdks/gf180mcuD/libs.ref 2>&1 | tr '\n' ' ')"
  echo "PDK_TECH $PDK_NAME: $(awk '/^ *version [0-9]/{print $2; exit}' $F/pdks/gf180mcuD/libs.tech/magic/gf180mcuD.tech 2>&1)"
  echo "PDK_DANGLING_LINKS $PDK_NAME $(find -L $F/pdks/gf180mcuD -type l 2>/dev/null | wc -l) (expected 0)"
}

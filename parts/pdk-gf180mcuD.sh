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
#  - Magic: the latest tag, 8.3.706 (1d42dfc, 2026-11-19; extraction fixes on top of 8.3.705). Since 8.3.705 (cc0360b)
#    it has two fixes the harness needs: `is_locked` initialized (1a6e9e5; with `locking disable` every cell read from
#    disk was "not writeable"), and GDS_FILE resolved relative to the cell (8.3.690 eeb1052; `make gds-prefill` lost
#    the seal ring and the top cell). Tested on the user's machine with 8.3.705 + e7a6777: padframe, wrappers,
#    symbols, gds-slots, user-id, gds-prefill all OK. For a newer Magic set MAGIC_TAG (a tag or branch of the repo).
#
# Network: ciel reads its index from https://fossi-foundation.github.io/ciel-releases (not in the Trusted list: use
# Network access "Custom", check "Also include default list", add fossi-foundation.github.io). The tarballs are GitHub
# release assets (github.com, release-assets.githubusercontent.com: in the default list). If the index host is
# refused, pdk_fetch retries through the GitHub API data source (api.github.com, also in the default list).
# Environment variables for sessions: PDK_ROOT=/foss/pdks PDK=gf180mcuD PDKPATH=/foss/pdks/gf180mcuD
# GF_PDK_OPTION=D STD_CELL_LIBRARY=gf180mcu_as_sc_mcu7t3v3 TMPDIR=/var/tmp
# (STD_CELL_LIBRARY: the harness's digital blocks use Avalon Semiconductors' 3.3 V cells, gf180mcu_as_sc_mcu7t3v3, in
# their LibreLane configs and in scripts/layout_setup.tcl; IIC-OSIC-TOOLS 2026.10 sets gf180mcu_fd_sc_mcu7t5v0.)
PDK_NAME=gf180mcuD
OPEN_PDKS_COMMIT=${OPEN_PDKS_COMMIT:-e7a6777d157a9d94c7ac757457b9e4309e9e9000}  # IIC-OSIC-TOOLS 2026.10 had 1689ac3f
# Libraries for `ciel enable`: all of them, as Belal did (the harness uses ocd_io, ocd_alpha_*, ocd_ip_sram, as_sc).
# On the user's machine: 1.1 GB for gf180mcuD. To fetch less: CIEL_LIB_OPTS="-l gf180mcu_fd_pr -l gf180mcu_ocd_io ..."
CIEL_LIB_OPTS=${CIEL_LIB_OPTS:--l all}
MAGIC_TAG=${MAGIC_TAG:-8.3.706}                       # git tag of github.com/RTimothyEdwards/magic
# netgen: the latest tag, 1.5.332 (2026-11-20). The archive's 1.5.324 (2026-09-26) is too old for the harness since
# Tim's d5ad122 (2026-11-19): verilog/gl/user_id_programming.v now uses a generate block with a parameter expression,
# which netgen's verilog reader understands only since its 2026-11-16/17 work (passed parameters, based constants).
NETGEN_TAG=${NETGEN_TAG:-1.5.332}                     # git tag of github.com/RTimothyEdwards/netgen
# netgen 1.5.332 cannot read that generate block itself either: it hands the module to yosys >= 0.67 with the built-in
# `read_slang` front end (netgen::yosys_check in tcltk/netgen.tcl.in). Ubuntu's yosys is 0.33. YoWASP's yosys (pip,
# WebAssembly, has read_slang) is installed as `yosys` in /usr/local/bin. YoWASP maps a private folder as /tmp, so
# netgen's scratch folder must not be under /tmp: set TMPDIR=/var/tmp in the environment variables (netgen uses
# $TMPDIR). Tested 2026-11-22: user_id_programming.v of d5ad122 "elaborated by yosys".
YOWASP_YOSYS=${YOWASP_YOSYS:-0.71.0.0.post1285}       # PyPI version of yowasp-yosys (Yosys 0.71)

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

# src_build <tool> <tag> <old version>: builds github.com/RTimothyEdwards/<tool> at <tag> into $F/tools/<tool>, where
# main.sh links it from. The archive's build is moved to $F/tools/<tool>-<old version> and put back if the build fails.
# Runs after `wait`, so apt is free. Magic about 25 s, netgen about 10 s with 2 CPUs (tested 2026-11-22).
src_apt() {
  apt-get install -y -qq --no-install-recommends build-essential m4 csh tcl-dev tk-dev libcairo2-dev libx11-dev \
      libncurses-dev libglu1-mesa-dev zlib1g-dev
}
src_build() {
  local tool=$1 tag=$2 oldv=$3 T=${1^^}; local src=/tmp/$tool-src old=$F/tools/$tool-$oldv
  git -c advice.detachedHead=false clone -q --depth 1 --branch $tag https://github.com/RTimothyEdwards/$tool $src \
    || { echo "${T}_FAILED fetch ($oldv kept)"; return 1; }
  [ -d $F/tools/$tool ] && [ ! -e $old ] && mv $F/tools/$tool $old
  ( cd $src && ./configure -q --prefix=$F/tools/$tool > /tmp/$tool-configure.log 2>&1 \
      && { [ $tool != magic ] || make database/database.h > /dev/null; } \
      && make -s -j"$(nproc)" > /tmp/$tool-make.log 2>&1 && make -s install > /tmp/$tool-install.log 2>&1 ) \
    && [ "$($F/tools/$tool/bin/$tool --version 2>/dev/null | tail -1)" = "$tag" ] \
    || { echo "${T}_FAILED build ($oldv kept; logs /tmp/$tool-*.log)"; tail -20 /tmp/$tool-make.log
         rm -rf $F/tools/$tool; [ -d $old ] && mv $old $F/tools/$tool; return 1; }
  rm -rf $src
  ok $T
  echo "${T}_VERSION $($F/tools/$tool/bin/$tool --version 2>/dev/null | tail -1)"
}

# yosys for netgen (see YOWASP_YOSYS above). The first run compiles the WebAssembly (35 s with 2 CPUs) into
# ~/.cache/YoWASP; done here in the background, so sessions start with it compiled.
yosys_wasm() {
  pip install -q --break-system-packages yowasp-yosys==$YOWASP_YOSYS || { echo "YOSYS_FAILED pip"; return 1; }
  printf '#!/bin/sh\n# yosys for netgen: YoWASP build with read_slang (claude-cloud-config parts/pdk-gf180mcuD.sh)\nexec yowasp-yosys "$@"\n' \
    > /usr/local/bin/yosys && chmod +x /usr/local/bin/yosys
  yosys -p "help read_slang" 2>&1 | grep -q 'read_slang \[options\]' || { echo "YOSYS_FAILED no read_slang"; return 1; }
  ok YOSYS
  echo "YOSYS_VERSION $(yosys -V)"
}

pdk_post() {
  ( yosys_wasm ) &
  src_apt || echo "SRC_APT_FAILED"
  src_build magic $MAGIC_TAG 8.3.685
  src_build netgen $NETGEN_TAG 1.5.324
  wait
  # not ported from IIC-OSIC-TOOLS: gzip of the Liberty files, and the two patches of the KLayout PyCells to
  # gdsfactory 9.x and the efuse PyCell (_build/images/open_pdks/patches/gf180mcu-*.patch). The PyCells need
  # gdsfactory in KLayout's Python; the GDS/LEF of the pad and standard cell libraries do not.
  echo "PDK_LIBS $PDK_NAME: $(ls $F/pdks/gf180mcuD/libs.ref 2>&1 | tr '\n' ' ')"
  # libraries the harness needs: pads, Avalon 3.3 V standard cells (digital blocks, LibreLane configs), alpha (text),
  # SRAM. Missing ones mean a ciel library set without them (CIEL_LIB_OPTS) or a different PDK version.
  for lib in gf180mcu_ocd_io gf180mcu_as_sc_mcu7t3v3 gf180mcu_ocd_alpha_large gf180mcu_ocd_ip_sram; do
    [ -d $F/pdks/gf180mcuD/libs.ref/$lib ] || echo "PDK_LIB_MISSING $lib"
  done
  echo "PDK_TECH $PDK_NAME: $(awk '/^ *version [0-9]/{print $2; exit}' $F/pdks/gf180mcuD/libs.tech/magic/gf180mcuD.tech 2>&1)"
  echo "PDK_DANGLING_LINKS $PDK_NAME $(find -L $F/pdks/gf180mcuD -type l 2>/dev/null | wc -l) (expected 0)"
}

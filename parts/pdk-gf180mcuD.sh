# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- PDK: gf180mcuD (GlobalFoundries 180 nm MCU, variant D; open_pdks build installed with ciel, as IIC-OSIC-TOOLS
# 2026.10 does) ----
# UNTESTED against the real ciel download (the session this was written in could not reach ciel's release index).
# Defines PDK_NAME, pdk_fetch (runs in the background, in parallel with the tools) and pdk_post (runs after `wait`).
# Needs network access to ciel's data source: https://fossi-foundation.github.io/ciel-releases and wherever the
# tarballs it lists are hosted. Add the hosts to the cloud environment's allowed domains if the log shows PDK_FAILED.
# Environment variables for sessions (from IIC-OSIC-TOOLS' sak-pdk-script.sh): PDK_ROOT=/foss/pdks PDK=gf180mcuD
# GF_PDK_OPTION=D STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0
PDK_NAME=gf180mcuD
OPEN_PDKS_COMMIT=1689ac3f2dc763876eaf967227c7dfe831b031ae  # IIC-OSIC-TOOLS 2026.10, _build/images/open_pdks/Dockerfile
# Extra options for `ciel enable`. Empty = ciel's default library set (what IIC-OSIC-TOOLS installs). To fetch less,
# e.g. CIEL_LIB_OPTS="-l gf180mcu_fd_pr -l gf180mcu_fd_io -l gf180mcu_fd_sc_mcu7t5v0" (one -l per library).
CIEL_LIB_OPTS=${CIEL_LIB_OPTS:-}

pdk_fetch() {
  pip install -q --break-system-packages --ignore-installed ciel \
    && ciel enable --pdk-root $F/pdks --pdk-family gf180mcu $CIEL_LIB_OPTS $OPEN_PDKS_COMMIT \
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

pdk_post() {
  # not ported from IIC-OSIC-TOOLS: gzip of the Liberty files, and the two patches of the KLayout PyCells to
  # gdsfactory 9.x and the efuse PyCell (_build/images/open_pdks/patches/gf180mcu-*.patch). The PyCells need
  # gdsfactory in KLayout's Python; the GDS/LEF of the pad and standard cell libraries do not.
  echo "PDK_LIBS $PDK_NAME: $(ls $F/pdks/gf180mcuD/libs.ref 2>&1 | tr '\n' ' ')"
  echo "PDK_DANGLING_LINKS $PDK_NAME $(find -L $F/pdks/gf180mcuD -type l 2>/dev/null | wc -l) (expected 0)"
}

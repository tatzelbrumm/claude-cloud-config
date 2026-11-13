# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- PDK: sky130A (SkyWater, open_pdks build installed with ciel, as IIC-OSIC-TOOLS 2026.10 does) ----
# UNTESTED against the real ciel download (the session this was written in could not reach ciel's release index).
# Defines PDK_NAME, pdk_fetch (runs in the background, in parallel with the tools) and pdk_post (runs after `wait`).
# Needs network access to ciel's data source: https://fossi-foundation.github.io/ciel-releases and wherever the
# tarballs it lists are hosted. Add the hosts to the cloud environment's allowed domains if the log shows PDK_FAILED.
PDK_NAME=sky130A
OPEN_PDKS_COMMIT=1689ac3f2dc763876eaf967227c7dfe831b031ae  # IIC-OSIC-TOOLS 2026.10, _build/images/open_pdks/Dockerfile
# Extra options for `ciel enable`. Empty = ciel's default library set (what IIC-OSIC-TOOLS installs). To fetch less,
# e.g. CIEL_LIB_OPTS="-l sky130_fd_pr -l sky130_fd_io -l sky130_fd_sc_hd" (one -l per library; names: `ciel enable --help`).
CIEL_LIB_OPTS=${CIEL_LIB_OPTS:-}

pdk_fetch() {
  pip install -q --break-system-packages --ignore-installed ciel \
    && ciel enable --pdk-root $F/pdks --pdk-family sky130 $CIEL_LIB_OPTS $OPEN_PDKS_COMMIT \
    || { echo "PDK_FAILED ciel enable"; return 1; }
  # sky130B is not wanted (IIC-OSIC-TOOLS removes it too)
  rm -rf $F/pdks/ciel/sky130/versions/*/sky130B $F/pdks/sky130B
  [ -d $F/pdks/sky130A ] || { echo "PDK_FAILED sky130A not found after ciel enable"; return 1; }
  ok PDK
  # Repair of the KLayout tech file shipped by open_pdks, copied from IIC-OSIC-TOOLS 2026.10
  # (_build/images/open_pdks/scripts/install_ciel.sh). It carries the generic "sky130" tech/layer-property naming and
  # the absolute base paths of the machine the PDK was built on. The guard notices when the workaround is unnecessary.
  SKY130A_LYT="$F/pdks/sky130A/libs.tech/klayout/tech/sky130A.lyt"
  if grep -q -e '>sky130<' -e 'sky130\.lyp' -e '<base-path>' "$SKY130A_LYT"; then
    sed -i 's/>sky130</>sky130A</g' "$SKY130A_LYT"
    sed -i 's/sky130.lyp/sky130A.lyp/g' "$SKY130A_LYT"
    sed -i '/<base-path>/c\ <base-path/>' "$SKY130A_LYT"
    sed -i '/<original-base-path>/c\ <original-base-path>$PDK_ROOT/$PDK/libs.tech/klayout</original-base-path>' "$SKY130A_LYT"
  else
    echo "sky130A.lyt needs no repair anymore (or is missing), this patch can be dropped"
  fi
}

pdk_post() {
  # not ported from IIC-OSIC-TOOLS: gzip of the Liberty files, the Magic bindkeys, the gdsfactory/kfactory patches of
  # the KLayout PyCells (libs.tech/klayout/python/cells). Add them here if a cloud flow needs them.
  echo "PDK_LIBS $PDK_NAME: $(ls $F/pdks/sky130A/libs.ref 2>&1 | tr '\n' ' ')"
  echo "PDK_DANGLING_LINKS $PDK_NAME $(find -L $F/pdks/sky130A -type l 2>/dev/null | wc -l) (expected 0)"
}

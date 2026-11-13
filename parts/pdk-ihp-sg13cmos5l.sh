# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- PDK: ihp-sg13cmos5l (IHP-Open-PDK, iic-jku fork, sparse checkout at PDK_REV) ----
# Defines PDK_NAME, pdk_fetch (runs in the background, in parallel with the tools) and pdk_post (runs after `wait`).
PDK_NAME=ihp-sg13cmos5l
PDK_REV=df4c5054ee8ca481c3eb873687274f28cdb50b1e          # the archive's OSDI models are compiled for this
# ihp-sg13cmos5l/libs.ref/sg13cmos5l_sram is a symlink to ihp-sg13g2/libs.ref/sg13g2_sram (44 MB). Not fetched by
# default; WITH_SRAM=1 fetches it. The stdcell schematics (84 symlinks into ihp-sg13g2, 1.2 MB) are always fetched.
WITH_SRAM=${WITH_SRAM:-0}

pdk_fetch() {
  S="/ihp-sg13cmos5l/ /ihp-sg13g2/libs.tech/klayout/python/ /ihp-sg13g2/libs.tech/klayout/tech/
     /ihp-sg13g2/libs.tech/xschem/ /ihp-sg13g2/libs.tech/ngspice/ /ihp-sg13g2/libs.tech/verilog-a/
     /ihp-sg13g2/libs.ref/sg13g2_stdcell/sch/"
  [ "$WITH_SRAM" = 1 ] && S="$S /ihp-sg13g2/libs.ref/sg13g2_sram/"
  git clone -q --filter=blob:none --no-checkout https://github.com/iic-jku/IHP-Open-PDK $F/pdks/IHP-Open-PDK \
    && cd $F/pdks/IHP-Open-PDK \
    && git sparse-checkout set --no-cone $S \
    && git checkout -q $PDK_REV \
    && git submodule update -q --init --depth 1 ihp-sg13g2/libs.tech/klayout/python/pycell4klayout-api \
         ihp-sg13g2/libs.tech/klayout/python/pypreprocessor \
    && ln -sfn $F/pdks/IHP-Open-PDK/ihp-sg13cmos5l $F/pdks/ihp-sg13cmos5l && ok PDK \
    && echo "PDK_DANGLING_LINKS libs.tech/klayout $(find $F/pdks/ihp-sg13cmos5l/libs.tech/klayout -xtype l | wc -l) (1 = README.md)" \
    && echo "PDK_DANGLING_LINKS libs.ref $(find $F/pdks/ihp-sg13cmos5l/libs.ref -xtype l | wc -l) (1 = sg13cmos5l_sram if WITH_SRAM=0, else 0)"
}

pdk_post() {
  # OSDI models: copy the prebuilt ones for PDK_REV; for another PDK commit compile them (about 20 s)
  O=$F/pdks/ihp-sg13cmos5l/libs.tech/ngspice/osdi; mkdir -p $O
  if ls $F/tools/osdi/ihp-sg13cmos5l-$PDK_REV/*.osdi > /dev/null 2>&1; then
    cp $F/tools/osdi/ihp-sg13cmos5l-$PDK_REV/*.osdi $O/ && ok OSDI
  else
    ( cd $F/pdks/ihp-sg13cmos5l/libs.tech/verilog-a && PATH=$F/tools/openvaf/bin:$PATH \
        ./openvaf-compile-va.sh --compile-model-generic && ok OSDI_COMPILED )
  fi
  # kpex 0.6.8 takes ihp-sg13cmos5l; the Chipalooza template Makefile passes ihp_sg13cmos5l
  K=$(command -v kpex) && [ ! -e $K.pip ] && mv $K $K.pip \
    && printf '#!/bin/bash\nexec %s.pip "${@/ihp_sg13cmos5l/ihp-sg13cmos5l}"\n' $K > $K && chmod +x $K
}

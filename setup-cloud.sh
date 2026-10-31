#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# Setup script for a Claude Code cloud environment (Ubuntu 24.04 x86_64). Paste it into the environment's
# "Setup script". Installs the prebuilt toolchain of github.com/tatzelbrumm/claude-cloud-config (IIC-OSIC-TOOLS
# 2026.10 pins), KLayout, klayout-pex and the IHP PDK. It compiles nothing, so it stays well under the ~5 min
# limit and the environment gets cached. Must exit 0. Log with times: /foss/setup.log
REPO=https://github.com/tatzelbrumm/claude-cloud-config
REV=main                                                  # branch or tag of REPO
PDK_REV=df4c5054ee8ca481c3eb873687274f28cdb50b1e          # the archive's OSDI models are compiled for this
export DEBIAN_FRONTEND=noninteractive
F=/foss; mkdir -p $F/pdks; L=$F/setup.log
t0=$(date +%s); ok() { echo "$1_OK $(( $(date +%s) - t0 ))s" >> $L; }
# runtime libraries of the prebuilt tools (from ldd), plus the KLayout package
( curl -fsSLo /tmp/klayout.deb https://www.klayout.org/downloads/Ubuntu-24/klayout_0.30.12-1_amd64.deb \
    || echo "KLAYOUT_DEB_FAILED"
  apt-get update -qq && apt-get install -y -qq --no-install-recommends $( [ -s /tmp/klayout.deb ] && echo /tmp/klayout.deb ) \
    xz-utils tcl tk tcl8.6 tk8.6 libtcl8.6 libtk8.6 libcairo2 libpixman-1-0 libpng16-16t64 libfreetype6 libfontconfig1 \
    libx11-6 libxext6 libxrender1 libxpm4 libxaw7 libxmu6 libxt6t64 libxft2 libxss1 libsm6 libice6 libxcb1 \
    libxcb-shm0 libxcb-render0 libgl1 libglx0 libglvnd0 libopengl0 libglu1-mesa libjpeg-turbo8 libreadline8t64 \
    libtinfo6 libfftw3-double3 libgomp1 libllvm18 libedit2 libxml2 libicu74 libffi8 libzstd1 python3-tk \
    && ok APT ) >> $L 2>&1 &
( pip install -q --break-system-packages klayout==0.30.12 klayout-pex==0.6.8 && ok PIP ) >> $L 2>&1 &
# the prebuilt tools: only tools/ is downloaded, not the sources
( git clone -q --depth 1 --filter=blob:none --no-checkout --branch $REV $REPO /tmp/ccc && cd /tmp/ccc \
  && git sparse-checkout set --no-cone /tools/ && git checkout -q \
  && tar -xJf tools/foss-tools-*.tar.xz -C / && ok TOOLS ) >> $L 2>&1 &
( git clone -q --filter=blob:none --no-checkout https://github.com/iic-jku/IHP-Open-PDK $F/pdks/IHP-Open-PDK \
  && cd $F/pdks/IHP-Open-PDK \
  && git sparse-checkout set --no-cone /ihp-sg13cmos5l/ /ihp-sg13g2/libs.tech/klayout/python/ \
       /ihp-sg13g2/libs.tech/xschem/ /ihp-sg13g2/libs.tech/ngspice/ /ihp-sg13g2/libs.tech/verilog-a/ \
  && git checkout -q $PDK_REV \
  && git submodule update -q --init --depth 1 ihp-sg13g2/libs.tech/klayout/python/pycell4klayout-api \
       ihp-sg13g2/libs.tech/klayout/python/pypreprocessor \
  && ln -sfn $F/pdks/IHP-Open-PDK/ihp-sg13cmos5l $F/pdks/ihp-sg13cmos5l && ok PDK ) >> $L 2>&1 &
wait
# OSDI models: copy the prebuilt ones for PDK_REV; for another PDK commit compile them (about 20 s)
O=$F/pdks/ihp-sg13cmos5l/libs.tech/ngspice/osdi; mkdir -p $O
if ls $F/tools/osdi/ihp-sg13cmos5l-$PDK_REV/*.osdi > /dev/null 2>&1; then
  cp $F/tools/osdi/ihp-sg13cmos5l-$PDK_REV/*.osdi $O/ && ok OSDI
else
  ( cd $F/pdks/ihp-sg13cmos5l/libs.tech/verilog-a && PATH=$F/tools/openvaf/bin:$PATH \
      ./openvaf-compile-va.sh --compile-model-generic && ok OSDI_COMPILED ) >> $L 2>&1
fi
# CACE 2.11.0 (the 2026.10 pin) under python3.12: python3 is 3.13 here, Ubuntu has no Tk for it, and CACE imports
# tkinter even on the command line. --ignore-installed blinker: pip can't remove Debian's blinker 1.7.0.
( python3.12 -m pip install -q --break-system-packages --ignore-installed blinker cace==2.11.0 && cace --version \
  && ok CACE ) >> $L 2>&1
# kpex 0.6.8 takes ihp-sg13cmos5l; the Chipalooza template Makefile passes ihp_sg13cmos5l
K=$(command -v kpex) && [ ! -e $K.pip ] && mv $K $K.pip \
  && printf '#!/bin/bash\nexec %s.pip "${@/ihp_sg13cmos5l/ihp-sg13cmos5l}"\n' $K > $K && chmod +x $K
for b in $F/tools/{xschem,magic,netgen,ngspice,openvaf}/bin/* $F/tools/sak/sak-*; do ln -sf "$b" /usr/local/bin/; done
rm -rf /tmp/ccc /tmp/klayout.deb
echo "SETUP_DONE $(( $(date +%s) - t0 ))s" >> $L
exit 0

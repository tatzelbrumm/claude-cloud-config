# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# ---- common part: runs the jobs in parallel, then the post steps; PDK-independent ----
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
# the PDK (parts/pdk-*.sh): fetched in parallel with the tools
( pdk_fetch ) >> $L 2>&1 &
wait
# the PDK's post steps, which need both the tools and the PDK
pdk_post >> $L 2>&1
# CACE 2.11.0 (the 2026.10 pin) under python3.12: python3 is 3.13 here, Ubuntu has no Tk for it, and CACE imports
# tkinter even on the command line. --ignore-installed blinker: pip can't remove Debian's blinker 1.7.0.
( python3.12 -m pip install -q --break-system-packages --ignore-installed blinker cace==2.11.0 && cace --version \
  && ok CACE ) >> $L 2>&1
for b in $F/tools/{xschem,magic,netgen,ngspice,openvaf}/bin/* $F/tools/sak/sak-*; do ln -sf "$b" /usr/local/bin/; done
rm -rf /tmp/ccc /tmp/klayout.deb
echo "SETUP_DONE $PDK_NAME $(( $(date +%s) - t0 ))s" >> $L
exit 0

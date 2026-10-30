#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Copied from sudelbuecher/cloud_environment.md (branch sudel_buecher of tatzelbrumm/sg13cmos5l_cm_ip__single2diff2single).
# Chipalooza sg13cmos5l toolchain for Claude Code cloud sessions (pins: IIC-OSIC-TOOLS 2026.10,
# sudelbuecher/cloud_environment.md on branch sudel_buecher). Must exit 0. Log: /foss/setup.log
export DEBIAN_FRONTEND=noninteractive
F=/foss; mkdir -p $F/pdks $F/tools $F/src; L=$F/setup.log; cd $F/src
t0=$(date +%s); ok() { echo "$1_OK $(( $(date +%s) - t0 ))s" >> $L; }
g() { git clone -q --filter=blob:none "$1" "$2" && git -C "$2" checkout -q "$3"; }    # url dir pin
curl -fsSLo klayout.deb https://www.klayout.org/downloads/Ubuntu-24/klayout_0.30.12-1_amd64.deb >> $L 2>&1 \
  || echo "KLAYOUT_DEB_FAILED" >> $L
apt-get update -qq >> $L 2>&1
apt-get install -y -qq --no-install-recommends $( [ -s klayout.deb ] && echo ./klayout.deb ) \
  build-essential autoconf automake libtool bison flex gawk m4 tcsh libncurses-dev libglu1-mesa-dev \
  libx11-dev libxpm-dev libxrender-dev libxcb1-dev libx11-xcb-dev libcairo2-dev libjpeg-dev tcl-dev tk-dev \
  libreadline-dev libfftw3-dev libxaw7-dev libxmu-dev libxext-dev libxft-dev libfontconfig1-dev \
  llvm-18-dev clang-18 libclang-18-dev >> $L 2>&1 && ok APT
pip install -q --break-system-packages klayout==0.30.12 klayout-pex==0.6.8 >> $L 2>&1 && ok PIP
( g https://github.com/StefanSchippers/xschem xschem d76e6cc74fdfa5de573a8ba14124ef00c611a9b6 && cd xschem \
  && ./configure --prefix=$F/tools/xschem && make -j4 && make install && ok XSCHEM ) >> $L 2>&1 &
( g https://github.com/RTimothyEdwards/magic magic 8.3.685 && cd magic \
  && ./configure --prefix=$F/tools/magic && make -j4 && make install && ok MAGIC ) >> $L 2>&1 &
( g https://github.com/RTimothyEdwards/netgen netgen 1.5.324 && cd netgen \
  && ./configure --prefix=$F/tools/netgen && make -j4 && make install && ok NETGEN ) >> $L 2>&1 &
( g https://github.com/danchitnis/ngspice-sf-mirror ngspice ngspice-47 && cd ngspice && ./autogen.sh \
  && ./configure --disable-debug --enable-openmp --with-x --with-readline=yes --enable-pss --enable-xspice \
       --with-fftw3=yes --enable-osdi --enable-klu --prefix=$F/tools/ngspice \
  && make -j4 && make install && ok NGSPICE ) >> $L 2>&1 &
( g https://github.com/arpadbuermen/OpenVAF OpenVAF dd05b5e2f97fcc8256a1dbf7144755a1ad3bf90a && cd OpenVAF \
  && cargo update -q && cargo build -q --release --features llvm18 --bin openvaf-r \
  && install -m 755 target/release/openvaf-r /usr/local/bin/ && ok OPENVAF ) >> $L 2>&1 &
( git clone -q --depth 1 --branch 2026.10 --filter=blob:none --no-checkout https://github.com/iic-jku/IIC-OSIC-TOOLS iic \
  && cd iic && git sparse-checkout set --no-cone /_build/images/iic-osic-tools/skel/foss/tools/sak/ \
  && git checkout -q 2026.10 && cp -r _build/images/iic-osic-tools/skel/foss/tools/sak $F/tools/ && ok SAK ) >> $L 2>&1 &
( git clone -q --filter=blob:none --no-checkout https://github.com/iic-jku/IHP-Open-PDK $F/pdks/IHP-Open-PDK \
  && cd $F/pdks/IHP-Open-PDK \
  && git sparse-checkout set --no-cone /ihp-sg13cmos5l/ /ihp-sg13g2/libs.tech/klayout/python/ \
       /ihp-sg13g2/libs.tech/xschem/ /ihp-sg13g2/libs.tech/ngspice/ /ihp-sg13g2/libs.tech/verilog-a/ \
  && git checkout -q df4c5054ee8ca481c3eb873687274f28cdb50b1e \
  && git submodule update -q --init --depth 1 ihp-sg13g2/libs.tech/klayout/python/pycell4klayout-api \
       ihp-sg13g2/libs.tech/klayout/python/pypreprocessor \
  && ln -sfn $F/pdks/IHP-Open-PDK/ihp-sg13cmos5l $F/pdks/ihp-sg13cmos5l && ok PDK ) >> $L 2>&1 &
wait
( cd $F/pdks/ihp-sg13cmos5l/libs.tech/verilog-a && ./openvaf-compile-va.sh --compile-model-generic && ok OSDI ) >> $L 2>&1
chmod +x $F/tools/sak/*        # the sak scripts come without exec bits
K=$(command -v kpex) && mv $K $K.pip && printf '#!/bin/bash\n# kpex 0.6.8 takes ihp-sg13cmos5l; the template Makefile passes ihp_sg13cmos5l\nexec %s.pip "${@/ihp_sg13cmos5l/ihp-sg13cmos5l}"\n' $K > $K && chmod +x $K
for b in $F/tools/{xschem,magic,netgen,ngspice}/bin/* $F/tools/sak/sak-*; do ln -sf "$b" /usr/local/bin/; done
cd / && rm -rf $F/src
echo "SETUP_DONE $(( $(date +%s) - t0 ))s" >> $L
exit 0

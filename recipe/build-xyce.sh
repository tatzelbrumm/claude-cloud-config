#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# Builds Xyce the way IIC-OSIC-TOOLS 2026.11 does (_build/images/xyce/scripts/install.sh, trilinos.reconfigure.sh,
# xyce.reconfigure.sh; ADMS from _build/images/base/scripts/72_install_adms.sh): ADMS, Trilinos 12.12.1 and Xyce
# 7.10.0 with MPI, installed to $TOOLS/xyce. Then, if an IHP sg13g2 PDK is present, its Xyce plugins
# (Xyce_Plugin_PSP103_VA.so, _r3_cmc.so, _mosvar.so) with the PDK's own libs.tech/verilog-a/adms-compile-va.sh.
#
# Not a setup script: it compiles for about 25 min (4 cores, Ubuntu 24.04 cloud container, 2026-11-28; Trilinos
# 500 s, Xyce 980 s, plugins 124 s). Run it once in a session and pack $TOOLS/xyce into an archive. Finished steps are
# skipped on a rerun. Log lines "STEP_OK <step> <seconds>" on stdout, build output in <workdir>/*.log.
#
# usage: build-xyce.sh [workdir]      env: TOOLS (default /foss/tools), PDK_ROOT (default /foss/pdks)
set -e
W=$(mkdir -p "${1:-$PWD/xycebuild}" && cd "${1:-$PWD/xycebuild}" && pwd)
TOOLS=${TOOLS:-/foss/tools}; PDK_ROOT=${PDK_ROOT:-/foss/pdks}
XYCE_COMMIT=Release-7.10.0; TRILINOS_COMMIT=trilinos-release-12-12-1
export DEBIAN_FRONTEND=noninteractive
t0=$(date +%s); ok() { echo "STEP_OK $1 $(( $(date +%s) - t0 ))s"; }
PKGS="build-essential gfortran cmake bison flex libfl-dev libtool autoconf automake libopenmpi-dev openmpi-bin
      libblas-dev liblapack-dev libsuitesparse-dev libfftw3-dev perl libxml-libxml-perl"
apt-get install -y -qq --no-install-recommends $PKGS > /dev/null 2>&1 \
  || { apt-get update -qq && apt-get install -y -qq --no-install-recommends $PKGS > /dev/null; }
ok APT
cd "$W"
if ! command -v admsXml > /dev/null; then
  [ -d adms ] || git clone -q --depth=1 https://github.com/Qucs/ADMS.git adms
  cmake -S adms -B adms/build -DCMAKE_BUILD_TYPE=RELEASE -DCMAKE_INSTALL_PREFIX=/usr/local > adms.log 2>&1
  cmake --build adms/build -j"$(nproc)" --target install >> adms.log 2>&1
fi
ok ADMS
if [ ! -x "$TOOLS/xyce/bin/Xyce" ]; then
  [ -d xyce ] || git clone -q --filter=blob:none --no-checkout https://github.com/Xyce/Xyce.git xyce
  cd xyce && git checkout -q $XYCE_COMMIT && ./bootstrap > "$W/bootstrap.log" 2>&1
  [ -d trilinos ] || git clone -q --filter=blob:none --no-checkout https://github.com/trilinos/Trilinos.git trilinos
  (cd trilinos && git checkout -q $TRILINOS_COMMIT); ok CLONE
  ARCHDIR=$W/xyce/xycelibs/parallel; FLAGS="-O3 -fPIC"
  if [ ! -d "$ARCHDIR/lib" ]; then
    mkdir -p trilinos/parallel_build && cd trilinos/parallel_build
    cmake -G "Unix Makefiles" -DCMAKE_C_COMPILER=mpicc -DCMAKE_CXX_COMPILER=mpic++ -DCMAKE_Fortran_COMPILER=mpif77 \
      -DCMAKE_CXX_FLAGS="$FLAGS" -DCMAKE_C_FLAGS="$FLAGS" -DCMAKE_Fortran_FLAGS="$FLAGS" -DCMAKE_INSTALL_PREFIX="$ARCHDIR" \
      -DCMAKE_MAKE_PROGRAM=make -DTrilinos_ENABLE_NOX=ON -DNOX_ENABLE_LOCA=ON -DTrilinos_ENABLE_EpetraExt=ON \
      -DEpetraExt_BUILD_BTF=ON -DEpetraExt_BUILD_EXPERIMENTAL=ON -DEpetraExt_BUILD_GRAPH_REORDERINGS=ON \
      -DTrilinos_ENABLE_TrilinosCouplings=ON -DTrilinos_ENABLE_Ifpack=ON -DTrilinos_ENABLE_Isorropia=ON \
      -DTrilinos_ENABLE_AztecOO=ON -DTrilinos_ENABLE_Belos=ON -DTrilinos_ENABLE_Teuchos=ON \
      -DTrilinos_ENABLE_COMPLEX_DOUBLE=ON -DTrilinos_ENABLE_Amesos=ON -DAmesos_ENABLE_KLU=ON \
      -DTrilinos_ENABLE_Amesos2=ON -DAmesos2_ENABLE_KLU2=ON -DAmesos2_ENABLE_Basker=ON -DTrilinos_ENABLE_Sacado=ON \
      -DTrilinos_ENABLE_Stokhos=ON -DTrilinos_ENABLE_Kokkos=ON -DTrilinos_ENABLE_Zoltan=ON \
      -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF -DTrilinos_ENABLE_CXX11=ON -DTPL_ENABLE_AMD=ON \
      -DAMD_LIBRARY_DIRS=/usr/lib/x86_64-linux-gnu -DTPL_AMD_INCLUDE_DIRS=/usr/include/suitesparse \
      -DTPL_ENABLE_BLAS=ON -DTPL_ENABLE_LAPACK=ON -DTPL_ENABLE_MPI=ON .. > "$W/trilinos_cmake.log" 2>&1
    make -j"$(nproc)" > "$W/trilinos_make.log" 2>&1 && make install >> "$W/trilinos_make.log" 2>&1
    cd "$W/xyce"
  fi
  ok TRILINOS
  mkdir -p parallel_build && cd parallel_build
  ../configure CXXFLAGS="-O3" ARCHDIR="$ARCHDIR" CPPFLAGS="-I/usr/include/suitesparse" --enable-mpi CXX=mpicxx \
    CC=mpicc F77=mpif77 --enable-stokhos --enable-amesos2 --enable-shared --enable-xyce-shareable \
    --enable-user-plugin --prefix="$TOOLS/xyce" > "$W/xyce_configure.log" 2>&1
  (cd src/DeviceModelPKG/ADMS && make -j"$(nproc)") > "$W/xyce_make.log" 2>&1
  # user_plugin: parallel admsXml runs truncate each other's preprocessed rlc.va; generate these serially (as IIC)
  make -C user_plugin -j1 N_DEV_ADMSrlc.C N_DEV_ADMSrlc_bootstrap.C >> "$W/xyce_make.log" 2>&1
  make -j"$(nproc)" >> "$W/xyce_make.log" 2>&1 && make install >> "$W/xyce_make.log" 2>&1
  find "$TOOLS/xyce" -type f -name '*.a' -delete
  printf 'xyce %s\ntrilinos %s\n' $XYCE_COMMIT $TRILINOS_COMMIT > "$TOOLS/xyce/SOURCES"
fi
"$TOOLS/xyce/bin/Xyce" -v | head -1; ok XYCE
# IHP sg13g2 plugins, if the PDK is there (the PDK script writes to ../xyce/plugins and reports done even on failure)
VA=$PDK_ROOT/ihp-sg13g2/libs.tech/verilog-a
if [ -f "$VA/adms-compile-va.sh" ]; then
  (cd "$VA" && PATH=$TOOLS/xyce/bin:$PATH bash adms-compile-va.sh) > "$W/plugins.log" 2>&1
  for p in PSP103_VA r3_cmc mosvar; do
    [ -f "$PDK_ROOT/ihp-sg13g2/libs.tech/xyce/plugins/Xyce_Plugin_$p.so" ] || { echo "PLUGIN_FAILED $p"; exit 1; }
  done
  ok PLUGINS
fi

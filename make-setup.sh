#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
#
# Builds a Setup script for a Claude Code cloud environment by concatenating files from parts/, in this order:
#   parts/header.sh  parts/pdk-<pdk>.sh  [parts/digital.sh]  parts/main.sh
# (main.sh ends with `exit 0`, so it must be last.) The result is one self-contained file to paste into the
# environment's "Setup script" field.
#
# usage: ./make-setup.sh <pdk> [digital]     writes setup-<pdk>[-digital].sh (ihp-sg13cmos5l: setup-cloud.sh)
#        ./make-setup.sh all                 rewrites the three committed scripts, without digital
set -e
cd "$(dirname "$0")"
PDKS=$(ls parts/pdk-*.sh | sed 's|parts/pdk-||; s|\.sh$||')

build() {   # build <pdk> <digital|""> ; prints the output file name and the parts used
  local pdk=$1 dig=$2 out parts
  [ -f parts/pdk-$pdk.sh ] || { echo "unknown pdk '$pdk'. available:" $PDKS >&2; exit 1; }
  out=setup-$pdk.sh
  [ "$pdk" = ihp-sg13cmos5l ] && out=setup-cloud.sh        # the name this script had before there were three PDKs
  parts="parts/header.sh parts/pdk-$pdk.sh"
  if [ "$dig" = digital ]; then parts="$parts parts/digital.sh"; out=${out%.sh}-digital.sh; fi
  parts="$parts parts/main.sh"
  cat $parts > $out
  chmod +x $out
  bash -n $out
  echo "$out <- $parts"
}

if [ "$1" = all ]; then
  for p in $PDKS; do build $p ""; done
else
  build "$1" "$2"
fi

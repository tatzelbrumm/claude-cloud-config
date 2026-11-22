#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Unpack what gds_pack.sh made. usage: gds_unpack.sh <dir with chunks and SHA256SUMS> [output dir, default .]
# Checks every chunk, joins and decompresses, then checks the result against the sha256 of the original file.
set -euo pipefail
d=$(cd "$1" && pwd); o=${2:-.}; mkdir -p "$o"; o=$(cd "$o" && pwd)
( cd "$d" && grep '\.xz\.part-' SHA256SUMS | sha256sum -c --quiet - )
name=$(ls "$d"/*.xz.part-* | head -1 | sed 's|.*/||; s|\.xz\.part-.*||')
cat "$d/$name".xz.part-* | xz -d > "$o/$name"
( cd "$o" && grep -v '\.xz\.part-' "$d/SHA256SUMS" | sha256sum -c - )

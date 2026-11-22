#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Pack a big file (the final GDS) for transfer through git: xz, split into chunks, checksums. Byte-exact round trip.
# usage: gds_pack.sh <file> <outdir> [chunk size, default 90M]  [PUSH_URL=<git url> PUSH_BRANCH=<branch>]
#   <outdir>/<name>.xz.part-aaa ...   chunks (GitHub rejects files over 100 MB; stay below)
#   <outdir>/SHA256SUMS               of the ORIGINAL file and of every chunk
#   <outdir>/MANIFEST.txt             sizes, xz settings, date, how to unpack
#   <outdir>/gds_unpack.sh            copy of the unpack script
# PUSH_URL + PUSH_BRANCH: commit <outdir> as ONE commit with no parent (orphan) and force-push it, replacing the branch.
# Permission to push that branch must come from the user. Compression: xz -9e -T0 (about 1.3 GB RAM per thread at -9e).
set -euo pipefail
f=$1; out=$2; chunk=${3:-90M}
[ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
name=$(basename "$f"); mkdir -p "$out"; here=$(cd "$(dirname "$0")" && pwd)
orig=$(stat -c %s "$f")
sha=$(sha256sum "$f" | cut -d' ' -f1)
xz -9e -T0 -c "$f" | split -b "$chunk" -a 3 - "$out/$name.xz.part-"
( cd "$out" && { echo "$sha  $name"; sha256sum "$name".xz.part-*; } > SHA256SUMS )
comp=$(cat "$out/$name".xz.part-* | wc -c)
cp "$here/gds_unpack.sh" "$out/"
cat > "$out/MANIFEST.txt" <<M
file: $name
original bytes: $orig
compressed bytes: $comp (xz -9e -T0, chunks of $chunk)
chunks: $(ls "$out/$name".xz.part-* | wc -l)
packed: $(date -u +%Y-%m-%dT%H:%MZ)
unpack: ./gds_unpack.sh <dir with the chunks> [output dir]   (cat chunks | xz -d, then sha256sum -c)
M
echo "packed $name: $orig -> $comp bytes in $(ls "$out/$name".xz.part-* | wc -l) chunk(s)"
if [ -n "${PUSH_URL:-}" ] && [ -n "${PUSH_BRANCH:-}" ]; then
  ( cd "$out" && rm -rf .git && git init -q && git checkout -q -b "$PUSH_BRANCH" && git add -A \
    && git -c user.name=cloud -c user.email=cloud@localhost commit -q -m "packed $name ($orig bytes)" \
    && git push -q --force "$PUSH_URL" "$PUSH_BRANCH" && echo "pushed to $PUSH_URL $PUSH_BRANCH"; rm -rf .git )
fi

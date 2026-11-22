#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Push the run logs out of a cloud container as a normal (append-only) commit on a log branch, so nothing depends on the
# container surviving. usage: push_logs.sh <git url> <branch> <log dir> [label]
#   Creates the branch as an orphan if it does not exist. Copies <log dir>/* (not subdirectories) to run-<id>/ on the
#   branch, <id> = the UTC time of the first call in this container (kept in <log dir>/.runid). Never force-pushes.
#   Exit code 1 if the push failed (the caller reports it and carries on). Logs only: no GDS, nothing over 20 MB.
set -euo pipefail
url=$1; br=$2; dir=$3; label=${4:-update}
[ -f "$dir/.runid" ] || date -u +%Y%m%dT%H%MZ > "$dir/.runid"
id=$(cat "$dir/.runid"); t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
if git ls-remote --exit-code --heads "$url" "$br" >/dev/null 2>&1; then
  git clone -q --depth 1 -b "$br" "$url" "$t/r"
else
  git init -q "$t/r"; git -C "$t/r" checkout -q --orphan "$br"
fi
cd "$t/r"; mkdir -p "run-$id"
for f in "$dir"/*; do [ -f "$f" ] || continue
  [ "$(stat -c %s "$f")" -le 20971520 ] || { echo "skipped (over 20 MB): $f"; continue; }
  cp "$f" "run-$id/"; done
git add -A
git -c user.name=cloud -c user.email=cloud@localhost commit -q -m "logs $label ($id)" || { echo "nothing new"; exit 0; }
git push -q "$url" "HEAD:$br" 2>&1 || { git pull -q --rebase "$url" "$br" 2>&1 && git push -q "$url" "HEAD:$br" 2>&1; } \
  || { echo "PUSH_LOGS_FAILED"; exit 1; }
echo "pushed logs ($label) to $br run-$id"

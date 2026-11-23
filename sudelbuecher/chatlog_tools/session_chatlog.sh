#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Verbatim chat log of the CURRENT session, from its raw transcript, for use inside a cloud session (also callable
# repeatedly: it rebuilds the whole log each time). Prints only counts. Exit 1 if the check finds anything missing or any
# reasoning in the log. usage: session_chatlog.sh <out.md> "<title>" "<model>" [transcript.jsonl]
#   transcript: default = the newest *.jsonl under ~/.claude/projects/. It is copied to /var/tmp/transcripts/ first
#   (context compaction rewrites the original). The raw transcript itself is NEVER pushed: it contains the reasoning.
set -euo pipefail
out=$1; title=$2; model=$3; here=$(cd "$(dirname "$0")" && pwd)
src=${4:-$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)}
[ -f "$src" ] || { echo "NO_TRANSCRIPT: no .jsonl under ~/.claude/projects/ (say so; do not reconstruct a log)"; exit 2; }
mkdir -p /var/tmp/transcripts; cp "$src" /var/tmp/transcripts/; t=/var/tmp/transcripts/$(basename "$src")
sid=$(basename "$src" .jsonl); h=$(mktemp)
sed "s|^# <Session title>.*|# $title|; /^<!-- Template for the header/d; s|^- \*\*Branches:\*\*.*|- **Branches:** the harness fork, branch main; the logs on its branch chipalooza_logs.|" "$here/header.md" > "$h"
python3 - "$h" "$sid" "$model" "$(date -u +%Y-%m-%d)" <<'PY'
import sys; p,sid,model,d=sys.argv[1:]
s=open(p).read()
s=s.replace("- **Session:** ","- **Session:** Claude Code cloud session `%s`, model %s. Rebuilt %s UTC. "%(sid,model,d),1)
open(p,'w').write(s)
PY
python3 "$here/build_chatlog.py" "$t" "$out" "$h" | head -1
python3 "$here/verify_chatlog.py" "$t" "$out" | tee /var/tmp/transcripts/verify.out | tail -3
rm -f "$h"
grep -q 'missing [1-9]' /var/tmp/transcripts/verify.out && { echo CHATLOG_CHECK_FAILED; exit 1; }
grep -q 'found in the log [1-9]' /var/tmp/transcripts/verify.out && { echo CHATLOG_CHECK_FAILED; exit 1; }
echo "chat log written: $out"

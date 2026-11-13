# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
"""Check a chat log built by build_chatlog.py against the raw transcript. Prints counts only.
usage: python3 verify_chatlog.py <transcript.jsonl> <log.md>
1. every user message (plain and mid-turn) and every visible assistant text block of the transcript is in the log
   verbatim (counted separately for records on and off the live path);
2. no 40-character window of any thinking block occurs in the log."""
import json, re, sys

recs = [json.loads(l) for l in open(sys.argv[1])]
log = open(sys.argv[2]).read()
by = {r['uuid']: r for r in recs if 'uuid' in r}
live, u = set(), recs[-1].get('uuid')
while u and u in by:
    live.add(u); r = by[u]; u = r.get('parentUuid') or r.get('logicalParentUuid')

want = []   # (on live path, text)
think = []
for r in recs:
    t, on = r.get('type'), r.get('uuid') in live
    if t == 'user' and not r.get('isMeta') and not r.get('isCompactSummary'):
        c = r['message'].get('content')
        if isinstance(c, str):
            s = re.sub(r'<system-reminder>.*?</system-reminder>', '', c, flags=re.S).strip()
            if s and not s.startswith('<task-notification>'):
                want.append((on, s))
    elif t == 'attachment':
        a = r.get('attachment', {})
        if a.get('type') == 'queued_command' and a.get('commandMode') == 'prompt' and isinstance(a.get('prompt'), str):
            want.append((on, a['prompt'].rstrip()))
    elif t == 'assistant':
        for b in r['message'].get('content', []):
            if b.get('type') == 'text' and b['text'].strip():
                want.append((on, b['text'].strip()))
            elif b.get('type') in ('thinking', 'redacted_thinking'):
                think.append(b.get('thinking') or '')

for on in (True, False):
    sel = [s for o, s in want if o == on]
    miss = sum(1 for s in sel if s not in log)
    print(('live path' if on else 'off the live path'), ': texts', len(sel), 'missing', miss)
W = 40
grams = {log[i:i + W] for i in range(len(log) - W + 1)}
hits = 0; windows = 0
for th in think:
    for i in range(0, max(0, len(th) - W + 1)):
        windows += 1
        if th[i:i + W] in grams:
            hits += 1
print('thinking blocks', len(think), 'with text', sum(1 for t in think if t), '40-char windows checked', windows,
      'found in the log', hits)

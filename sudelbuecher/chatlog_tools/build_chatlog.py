# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
"""Build the verbatim chat log of cloud session C3 from its raw transcript (sudelbuecher/verbatim_chatlog_recovery/
verbatim-chatlog-export.md). usage: python3 build_chatlog.py <transcript.jsonl> <out.md> <header.md>

User messages and visible assistant text verbatim; tool calls as *[ ]* summaries (action and observable result only);
agent hand-backs, task notifications, stop-hook feedback and the context compaction marked. Thinking blocks are never
read into the output. Prints only counts."""
import json, re, sys

src, out, header = sys.argv[1:4]
recs = [json.loads(l) for l in open(src)]
by = {r['uuid']: r for r in recs if 'uuid' in r}

# live path: parentUuid back from the last record (logicalParentUuid across the compaction boundary)
live, u = [], recs[-1].get('uuid')
while u:
    r = by.get(u)
    if r is None:
        break
    live.append(r)
    u = r.get('parentUuid') or r.get('logicalParentUuid')
live.reverse()
live_ids = {r['uuid'] for r in live}

# agent ids -> description (Agent tool_use description; agentId printed in its tool_result)
desc_of_tool = {}
agent_name = {}
for r in recs:
    if r.get('type') == 'assistant':
        for b in r['message'].get('content', []):
            if b.get('type') == 'tool_use' and b.get('name') == 'Agent':
                desc_of_tool[b['id']] = b['input'].get('description', 'agent')
for r in recs:
    if r.get('type') == 'user' and isinstance(r['message'].get('content'), list):
        for b in r['message']['content']:
            if b.get('type') == 'tool_result' and b.get('tool_use_id') in desc_of_tool:
                txt = b['content'] if isinstance(b['content'], str) else ' '.join(
                    c.get('text', '') for c in b['content'] if isinstance(c, dict))
                m = re.search(r'agentId: (\w+)', txt)
                if m:
                    agent_name[m.group(1)] = desc_of_tool[b['tool_use_id']]

def tool_line(b):
    n, i = b.get('name'), b.get('input', {})
    if n == 'Bash':
        if i.get('description'):
            return 'Bash: ' + i['description'].rstrip('.') + '.'
        first = next((l.strip() for l in i.get('command', '').split('\n') if l.strip()), '')
        first = first.replace('`', "'")
        return 'Bash: `' + first[:100] + ('` …' if len(first) > 100 or '\n' in i.get('command', '').strip() else '`')
    if n in ('Read', 'Write', 'Edit'):
        return f"{n} `{i.get('file_path', '')}`."
    if n == 'Agent':
        return f"Agent started: {i.get('description', '')}."
    if n == 'SendMessage':
        return f"SendMessage to an agent: {i.get('summary', '')}."
    if n == 'SendUserFile':
        files = ', '.join('`' + f.split('/')[-1] + '`' for f in i.get('files', []))
        cap = i.get('caption')
        return f"Sent to the user: {files}" + (f' (caption: "{cap}")' if cap else '') + '.'
    if n == 'Skill':
        return f"Skill loaded: {i.get('skill', '')}."
    if n == 'ToolSearch':
        return f"ToolSearch: {i.get('query', '')}."
    if n == 'Monitor':
        return f"Monitor started: {i.get('description', '')}."
    if n == 'TaskStop':
        return 'TaskStop: a background task stopped.'
    return f'{n} call.'

def result_note(b):
    if not b.get('is_error'):
        return None
    txt = b['content'] if isinstance(b['content'], str) else ' '.join(
        c.get('text', '') for c in b['content'] if isinstance(c, dict))
    first = re.sub(r'<[^>]+>', '', txt).strip().split('\n')[0][:160]
    return f'Result: error ({first}).'

def flush(lines, buf):
    if buf:
        body = '  \n'.join(buf)
        lines += ['*[' + body + ']*', '']
        buf.clear()

def ts(r):
    return r['timestamp'][:16].replace('T', ' ') + ' UTC'

lines = [open(header).read().rstrip('\n'), '']
buf, turn = [], 0
stats = dict(user=0, user_mid=0, asst_text=0, tools=0, handback=0, notif=0, hook=0)
user_texts, asst_texts = [], []
for r in live:
    t = r.get('type')
    if t == 'attachment':
        a = r.get('attachment', {})
        if a.get('type') == 'queued_command':
            p = a.get('prompt')
            if a.get('commandMode') == 'prompt' and isinstance(p, str):
                flush(lines, buf)
                lines += [f'**User (mid-turn, {ts(r)}):**', '', p.rstrip(), '']
                stats['user_mid'] += 1; user_texts.append(p.rstrip())
            elif isinstance(p, str) and '<task-notification>' in p:
                m = re.search(r'<summary>(.*?)</summary>', p, re.S)
                buf.append('Task notification: ' + (m.group(1).strip() if m else 'background task event') + '.')
                stats['notif'] += 1
        continue
    if t == 'user':
        c = r['message'].get('content')
        if r.get('isCompactSummary'):
            flush(lines, buf)
            lines += [f'*[Context compacted ({ts(r)}): the session continued from an automatic summary of the '
                      'conversation so far; the summary is not reproduced here.]*', '']
            continue
        if isinstance(c, str):
            s = re.sub(r'<system-reminder>.*?</system-reminder>', '', c, flags=re.S).strip()
            if r.get('isMeta'):
                if s.startswith('Another Claude session sent a message'):
                    m = re.search(r'agent-message from="(\w+)"', s)
                    who = agent_name.get(m.group(1), 'a subagent') if m else 'a subagent'
                    n = s.count('\n') + 1
                    buf.append(f'Hand-back report of agent "{who}" arrived ({n} lines).')
                    stats['handback'] += 1
                elif s.startswith('Stop hook feedback'):
                    flush(lines, buf)
                    lines += ['**Stop hook:**', '', s, '']
                    stats['hook'] += 1
                continue
            if s.startswith('<task-notification>'):
                m = re.search(r'<summary>(.*?)</summary>', s, re.S)
                buf.append('Task notification: ' + (m.group(1).strip() if m else 'background task event') + '.')
                stats['notif'] += 1
                continue
            flush(lines, buf)
            turn += 1
            lines += [f'## Turn {turn} ({ts(r)})', '', '**User:**', '', s, '']
            stats['user'] += 1; user_texts.append(s)
            continue
        if isinstance(c, list):
            for b in c:
                if b.get('type') == 'tool_result':
                    n = result_note(b)
                    if n:
                        buf.append(n)
        continue
    if t == 'assistant':
        for b in r['message'].get('content', []):
            if b.get('type') == 'text' and b['text'].strip():
                flush(lines, buf)
                lines += ['**Assistant:**', '', b['text'].strip(), '']
                stats['asst_text'] += 1; asst_texts.append(b['text'].strip())
            elif b.get('type') == 'tool_use':
                buf.append(tool_line(b)); stats['tools'] += 1
flush(lines, buf)
lines += ['---', '', f'*[End of the export: the last record on the live path is {live[-1]["uuid"]} '
          f'({ts(live[-1])}). Later turns are not included.]*', '']
open(out, 'w').write('\n'.join(lines))
print('records', len(recs), 'live path', len(live), 'turns', turn, stats)
print('first live record', live[0]['timestamp'], 'last', live[-1]['timestamp'])
json.dump({'user': user_texts, 'asst': asst_texts}, open(out + '.check.json', 'w'))

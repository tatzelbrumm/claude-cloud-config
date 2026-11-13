<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# CLAUDE.md — `sudel_buecher` worktree of `claude-cloud-config`

This is the `sudel_buecher` **orphan branch** of `tatzelbrumm/claude-cloud-config`, checked out as a separate
**git worktree** next to the main checkout (see "Setup" below). It holds the record around the setup scripts: chat logs,
run logs, notes. No setup scripts or tools live here; they are on `main`. The branch shares the repository's object
store with the main checkout but has no history in common with it, so design data (`main`) and exploration/documentation
(here) never mix. The same scheme as in `sg13cmos5l_cm_ip__single2diff2single`, whose `CLAUDE.md` section 6 is the model.

## What is filed where

- `sudelbuecher/chatlog/` — one verbatim chat log per session, `<date>_<model>_<topic>.md`, indexed in
  `sudelbuecher/chatlog/README.md` (one link and one sentence per log; also lists logs that are still pending).
- `sudelbuecher/chatlog_tools/` — `build_chatlog.py` and `verify_chatlog.py`, copied unchanged from
  `sg13cmos5l_cm_ip__single2diff2single` (branch `sudel_buecher`, `sudelbuecher/design_considerations/pad_buffer_layout/pad_cell_s2d/chatlog_tools/`),
  and `header.md`, a template for the header of a log.
- `sudelbuecher/verbatim_chatlog_recovery/verbatim-chatlog-export.md` — how to ask for and build a log (copied).
- `sudelbuecher/notes/` — summaries of decisions and findings. **Written by the assistant, not verbatim; never a chat log.**
- `sudelbuecher/logs/<branch>/` — tee'd output of runs, filed by the branch that produced it, listed in
  `sudelbuecher/MANIFEST.tsv` (git stores no mtimes).

## Chat-log rule

Never create or append to a `chatlog/*.md` file unless the user explicitly asks for one. When asked, it is **verbatim,
never paraphrased**, extracted by script from the session's raw transcript
(`~/.claude/projects/<project>/<session-id>.jsonl`) with `build_chatlog.py` and checked with `verify_chatlog.py`
(usage in their docstrings; they print only counts). Tool calls are the only thing elided, as `*[bracketed italic
summaries]*`. The internal reasoning stays out. Copy the transcript aside first: context compaction rewrites it.

**If the session has no raw transcript** (a cloud session whose container has no `~/.claude/projects/`; true for the
session of 2026-11-13), do not reconstruct a log from context or memory. Say so, add the log to the "Pending" list in
`chatlog/README.md`, and make it where the transcript exists (a Claude Code session on the linked computer), or from an
export of the chat if `build_chatlog.py` is extended to read it.

## Setup of the worktree (once per clone)

From the main checkout of `claude-cloud-config`, with `<dir>` = `../claude-cloud-config_sudelbuecher`:

- branch exists on the remote (the normal case): `git fetch origin sudel_buecher && git worktree add <dir> sudel_buecher`
- first creation, with no history in common with `main`: `git worktree add --orphan -b sudel_buecher <dir>`
  (needs git 2.42 or newer), then `git push -u origin sudel_buecher` from inside `<dir>`.

Commit here only from inside `<dir>`, and never put files of `main` in it.

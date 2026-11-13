<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# CLAUDE.md — claude-cloud-config

Prebuilt IIC-OSIC-TOOLS 2026.10 toolchain and Setup scripts for Claude Code cloud environments, one PDK per
environment (ihp-sg13cmos5l, sky130A, gf180mcuD). See `README.md`. Edit `parts/`, then run `./make-setup.sh all` and
commit the parts and the generated scripts together; never edit a generated `setup-*.sh` by hand.

## Where the record lives

On the **`sudel_buecher`** orphan branch (no history in common with this branch), checked out as a git worktree
`../claude-cloud-config_sudelbuecher`: chat logs, run logs, notes. Rules and setup of the worktree are in the
`CLAUDE.md` of that branch. Design data stays here; exploration and documentation go there.

**Chat-log rule:** never create or append to a chat log unless the user explicitly asks for one; when asked, it is
verbatim, built by script from the session's raw transcript, never retyped or paraphrased. If the session has no raw
transcript, say so instead of reconstructing one. Summaries of decisions are `notes/`, never `chatlog/`.

<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# Chatlog index

One link and one sentence per log. Rules and tools: `CLAUDE.md` at the root of this branch.

- [2026-11-22 Sonnet 5.5, gf180mcuD PDK download fix](2026-11-22_sonnet_gf180_pdk_download_fix.md): why ciel could not
  download the PDK in the cloud environment (index redirect to a dead host, GitHub API 403), the `ciel_enable` fallback
  in `main`, and the first log made from a raw transcript. Covers the session up to the request for the log.
  Note: `build_chatlog.py` and `verify_chatlog.py` now also handle user messages with attached images (list content
  with `text` blocks); before, such a message was silently skipped by both, so the check said "0 missing" while the
  message was absent. The transcript's trailing records without a `uuid` (title, last-prompt) were cut off first, because
  the builder starts the live path at the last record.

## Pending

- 2026-11-13, claude.ai Project "chipalooza gf180", cloud session `session_01XU3KH5axhpi3C2PpQsrPoE` (model Sonnet 5.5):
  moving the IIC-OSIC-TOOLS cloud setup from sg13cmos5l to sky130A and gf180mcuD, and setting up this branch.
  **Not made**: the cloud container of that session has no raw transcript (`~/.claude/projects/` does not exist, and no
  file carries the session id), and a log must not be retyped. Needs the transcript, from a Claude Code session on the
  linked computer, or an export of the chat plus a `build_chatlog.py` that reads it.
  The decisions and findings of that session are summarized (not verbatim) in
  `../notes/2026-11-13_multi_pdk_cloud_setup.md`.
  The same session continued until 2026-11-19 (Opus 5.5 from 2026-11-19 01:24 Berlin): GF180 harness padframe,
  timestamp mismatches, Magic 8.3.693, hand-off. Still no raw transcript. Its part up to 2026-11-18 exists as a log built
  from nine text copies of the app chat (not a transcript export), in `gf180_cm_ip__single2diff2single`, branch
  `sudel_buecher`, `sudelbuecher/chatlog/2026-11-13_sonnet_cloud_config_and_gf180_pad_work.md`. Summary of the rest:
  `../notes/2026-11-19_gf180_harness_handoff.md`.

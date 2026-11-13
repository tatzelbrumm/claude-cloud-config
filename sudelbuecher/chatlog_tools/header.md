<!--
SPDX-FileCopyrightText: 2026 Christoph Maier
SPDX-License-Identifier: Apache-2.0
-->
# <Session title> (<first date> to <last date>)

<!-- Template for the header passed to build_chatlog.py (third argument). Fill in the <...> parts. -->

- **Session:** <Claude Code cloud session (https://claude.ai/code/session_...) | Cowork | claude.ai chat>, model <model>.
- **Branches:** <design branch>, notes `sudel_buecher`. Notes: `sudelbuecher/notes/<file>.md`.
- **What is verbatim:** Christoph's messages (as **User**) and the assistant's visible replies, as written.
  - Tool calls appear as `*[ ]*` summaries: action and observable result only (errors and refusals noted).
  - Messages that did not come from Christoph are labeled: subagent reports, background-task notices, and the
    repository's stop hook.
  - The internal reasoning is not included.
- **How it was made:** extracted by script (`build_chatlog.py`, in `sudelbuecher/chatlog_tools/`) from the session's raw
  transcript, along the live path of `parentUuid`, and checked by script (`verify_chatlog.py`): every message and reply
  present verbatim, and no 40-character window of the reasoning in the file.
- **Times:** UTC. Christoph's clock (Europe/Berlin) is one hour ahead.

#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Push the log directory every <interval> seconds (default 120) with push_logs.sh, until killed. Run it in the background
# (nohup ... &) at the start of a cloud session, so that even a step of several hours has its log in the repository
# within minutes. usage: push_logs_loop.sh <git url> <branch> <log dir> [interval]
here=$(cd "$(dirname "$0")" && pwd)
while true; do
  "$here/push_logs.sh" "$1" "$2" "$3" "periodic $(date -u +%H:%M)" || echo "$(date -u +%T) push failed, will retry"
  sleep "${4:-120}"
done

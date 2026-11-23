#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Run one build step with a log, the real exit code and its duration, then push the logs. Run it from the harness checkout.
# usage: nohup run_step.sh <name> <command ...> > /dev/null 2>&1 &      then poll:  cat /var/tmp/runs/<name>.status
#   /var/tmp/runs/<name>.log     stdout+stderr of the command
#   /var/tmp/runs/<name>.status  "START <time> <command>" then "END <time> rc=<exit code> seconds=<n>"
# Needs /var/tmp/env.sh (PUSH_URL, LOGS_BRANCH, SB). Without nohup/& it runs in the foreground and prints the status line.
. /var/tmp/env.sh
name=$1; shift; d=/var/tmp/runs; mkdir -p $d
t0=$(date +%s); echo "START $(date -u +%T) $*" > $d/$name.status
"$@" > $d/$name.log 2>&1; rc=$?
echo "END $(date -u +%T) rc=$rc seconds=$(( $(date +%s) - t0 ))" >> $d/$name.status
$SB/harness_tools/push_logs.sh "$PUSH_URL" "$LOGS_BRANCH" $d "$name rc=$rc" > /dev/null 2>&1 || echo "PUSH_LOGS_FAILED after $name" >> $d/$name.status
tail -1 $d/$name.status
exit $rc

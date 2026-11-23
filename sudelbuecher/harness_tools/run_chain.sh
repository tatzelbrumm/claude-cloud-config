#!/bin/bash
# SPDX-FileCopyrightText: 2026 Christoph Maier
# SPDX-License-Identifier: Apache-2.0
# Run the Chipalooza build steps one after another with run_step.sh (log, exit code, seconds, push after each step).
# Run it from the harness checkout, in the background:  nohup run_chain.sh > /dev/null 2>&1 &     then poll /var/tmp/runs/chain.status
# usage: run_chain.sh [step ...]      default = README order:
#   clean-config config padframe wrappers symbols gds-slots user-id projects-gds gds-prefill gds-final drc-final
#   extract-sch-top extract-top lvs-top        (each step is `make <step>`)
# Stops at the first failing step, except those in CONTINUE_ON (default "projects-gds lvs-top"). Skips steps whose
# /var/tmp/runs/<step>.status already ends in rc=0 (so a restarted chain resumes). Environment: CHATLOG_MODEL=<model> also
# rebuilds the chat log after every step (chatlog_tools/session_chatlog.sh).
# /var/tmp/runs/chain.status: one line per step ("<time> <step> rc=<n> seconds=<n>"), then CHAIN_DONE or CHAIN_STOPPED <step>.
. /var/tmp/env.sh
d=/var/tmp/runs; mkdir -p $d
steps=("$@"); [ ${#steps[@]} -gt 0 ] || steps=(clean-config config padframe wrappers symbols gds-slots user-id projects-gds
  gds-prefill gds-final drc-final extract-sch-top extract-top lvs-top)
cont=${CONTINUE_ON:-"projects-gds lvs-top"}
for s in "${steps[@]}"; do
  if grep -q 'rc=0' $d/$s.status 2>/dev/null; then echo "$(date -u +%T) $s skipped (already rc=0)" >> $d/chain.status; continue; fi
  $SB/harness_tools/run_step.sh $s make $s > /dev/null 2>&1; rc=$?
  echo "$(date -u +%T) $s $(tail -1 $d/$s.status | grep -o 'rc=.*')" >> $d/chain.status
  [ -n "${CHATLOG_MODEL:-}" ] && $SB/chatlog_tools/session_chatlog.sh $d/chatlog.md "Chipalooza cloud build" "$CHATLOG_MODEL" > /dev/null 2>&1
  if [ $rc -ne 0 ] && ! [[ " $cont " == *" $s "* ]]; then echo "CHAIN_STOPPED $s" >> $d/chain.status
    $SB/harness_tools/push_logs.sh "$PUSH_URL" "$LOGS_BRANCH" $d "chain stopped at $s" > /dev/null 2>&1; exit $rc; fi
done
echo CHAIN_DONE >> $d/chain.status
$SB/harness_tools/push_logs.sh "$PUSH_URL" "$LOGS_BRANCH" $d "chain done" > /dev/null 2>&1

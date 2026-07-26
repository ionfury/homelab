#!/usr/bin/env bash
# kubectl audit log
#
# Appends all kubectl commands (with timestamp and full command) to
# ~/.claude/kubectl-audit.log for forensic tracing.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if echo "$CMD" | grep -qE '\bkubectl\b'; then
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] $CMD" >> ~/.claude/kubectl-audit.log
fi

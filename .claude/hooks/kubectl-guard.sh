#!/usr/bin/env bash
# kubectl cluster mutability guard
#
# Blocks mutating kubectl commands targeting the integration or live clusters
# unless a one-shot approval token exists at /tmp/kubectl-<cluster>-approved.
#
# Approval flow:
#   1. This hook blocks and prints instructions
#   2. Claude asks the user for confirmation in the conversation
#   3. User confirms -> Claude runs: touch /tmp/kubectl-<cluster>-approved
#   4. Claude retries the kubectl command
#   5. This hook consumes the token and allows the command (one-shot)

set -euo pipefail

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only intercept kubectl commands
if ! echo "$CMD" | grep -qE '\bkubectl\b'; then
  exit 0
fi

# Only intercept mutating subcommands
MUTATING='\b(apply|delete|patch|edit|replace|create|scale|drain|taint|cordon|uncordon|label|annotate|set)\b'
if ! echo "$CMD" | grep -qE "$MUTATING"; then
  exit 0
fi

# Only intercept protected clusters (integration, live)
if ! echo "$CMD" | grep -qE -- '--context (integration|live)'; then
  exit 0
fi

CLUSTER=$(echo "$CMD" | grep -oP '(?<=--context )(integration|live)')
APPROVAL_TOKEN="/tmp/kubectl-${CLUSTER}-approved"

if [[ -f "$APPROVAL_TOKEN" ]]; then
  rm -f "$APPROVAL_TOKEN"
  exit 0
fi

echo "BLOCKED: Direct mutation on the '${CLUSTER}' cluster requires explicit approval." >&2
echo "" >&2
echo "  This cluster is managed by Flux. Prefer committing to git and letting Flux reconcile." >&2
echo "  For emergency direct access, approve this specific command by running:" >&2
echo "" >&2
echo "    touch ${APPROVAL_TOKEN}" >&2
echo "" >&2
echo "  The approval token is one-shot and will be consumed immediately on use." >&2
exit 2

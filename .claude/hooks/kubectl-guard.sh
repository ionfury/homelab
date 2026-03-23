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

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Extract only lines where kubectl is directly invoked:
# kubectl appears at start-of-line or after a shell operator (; & ( |)
# This avoids matching kubectl in heredoc content, strings, or comments.
KUBECTL_INVOCATIONS=$(echo "$CMD" | grep -E '(^|[;&(|])[[:space:]]*(KUBECONFIG=[^[:space:]]+ +)?kubectl[[:space:]]' || true)

if [ -z "$KUBECTL_INVOCATIONS" ]; then
  exit 0
fi

# Only intercept mutating subcommands
MUTATING='\b(apply|delete|patch|edit|replace|create|scale|drain|taint|cordon|uncordon|label|annotate|set)\b'
if ! echo "$KUBECTL_INVOCATIONS" | grep -qE "$MUTATING"; then
  exit 0
fi

# Only intercept protected clusters (integration, live)
if ! echo "$KUBECTL_INVOCATIONS" | grep -qE -- '--context (integration|live)'; then
  exit 0
fi

CLUSTER=$(echo "$KUBECTL_INVOCATIONS" | grep -oE -- '--context (integration|live)' | awk '{print $2}' | head -1)
APPROVAL_TOKEN="/tmp/kubectl-${CLUSTER}-approved"

if [[ -f "$APPROVAL_TOKEN" ]]; then
  rm -f "$APPROVAL_TOKEN"
  exit 0
fi

echo "BLOCKED: Direct mutation on the '${CLUSTER}' cluster requires explicit approval." >&2
echo "" >&2
echo "  This cluster is managed by Flux. Prefer committing to git and letting Flux reconcile." >&2
echo "  For emergency direct access, YOU must create the approval token:" >&2
echo "" >&2
echo "    ! touch ${APPROVAL_TOKEN}" >&2
echo "" >&2
echo "  Run this in the Claude Code prompt (the ! prefix runs it as your command," >&2
echo "  not Claude's). The token is one-shot and will be consumed immediately on use." >&2
exit 2

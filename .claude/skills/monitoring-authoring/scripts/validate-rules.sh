#!/usr/bin/env bash
# validate-rules.sh — Validate PrometheusRule manifests before committing
#
# Usage:
#   ./validate-rules.sh <rules-file.yaml>
#   ./validate-rules.sh kubernetes/platform/config/monitoring/cilium-alerts.yaml
#
# Requires:
#   - kubectl configured for target cluster
#   - promtool (from prometheus package, or: brew install prometheus)
#
# Steps performed:
#   1. kubectl apply --dry-run=server to catch CRD validation errors
#   2. promtool check rules on extracted PromQL expressions

set -euo pipefail

RULES_FILE="${1:-}"

if [[ -z "$RULES_FILE" ]]; then
  echo "Usage: $0 <rules-file.yaml>" >&2
  exit 1
fi

if [[ ! -f "$RULES_FILE" ]]; then
  echo "Error: file not found: $RULES_FILE" >&2
  exit 1
fi

echo "==> Step 1: kubectl dry-run validation"
kubectl apply --dry-run=server -f "$RULES_FILE"
echo "    PASSED"

echo "==> Step 2: promtool check rules"
# Extract just the spec.groups section into a temp file promtool understands
TMPFILE=$(mktemp /tmp/promrules-XXXXXX.yaml)
trap 'rm -f "$TMPFILE"' EXIT

# promtool expects: groups: [...]  at the top level
python3 - "$RULES_FILE" "$TMPFILE" <<'EOF'
import sys, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
groups = doc.get("spec", {}).get("groups", [])
with open(sys.argv[2], "w") as f:
    yaml.dump({"groups": groups}, f)
EOF

promtool check rules "$TMPFILE"
echo "    PASSED"

echo ""
echo "All validations passed for: $RULES_FILE"

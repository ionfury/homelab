#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  CHECKING ALERTMANAGER"
echo "============================================================"
echo ""

AM_POD=$(kubectl --context "${CONTEXT}" -n monitoring get pods \
  -l app.kubernetes.io/name=alertmanager \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "${AM_POD}" ]; then
  echo "WARNING: Alertmanager pod not found in monitoring namespace -- skipping alert check."
  echo ""
  exit 0
fi

echo "Querying Alertmanager for firing alerts..."
FIRING=$(kubectl --context "${CONTEXT}" -n monitoring exec "${AM_POD}" -c alertmanager -- \
  wget -qO- \
  'http://localhost:9093/api/v2/alerts?active=true&silenced=false&inhibited=false' \
  2>/dev/null | python3 -c "
import json, sys
try:
    alerts = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ignore = {'Watchdog', 'InfoInhibitor'}
firing = [
    a['labels'].get('alertname', 'unknown')
    for a in alerts
    if a.get('status', {}).get('state') == 'active'
    and a['labels'].get('alertname') not in ignore
]
print('\n'.join(firing))
" | grep . || true)

if [ -n "${FIRING}" ]; then
  echo "WARNING: Firing alerts detected:"
  echo "${FIRING}"
else
  echo "No firing alerts."
fi

echo ""

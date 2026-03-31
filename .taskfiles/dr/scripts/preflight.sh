#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  DR EXERCISE PREFLIGHT"
echo "============================================================"
echo ""
echo "Exercise ID: ${EXERCISE_ID}"
echo "Cluster:     ${CONTEXT}"
echo ""

echo "Checking dev cluster connectivity..."
if ! kubectl --context "${CONTEXT}" cluster-info &>/dev/null; then
  echo "FAIL: Cannot connect to dev cluster. Run 'task k8s:kubeconfig-sync' first."
  exit 1
fi
echo "  dev cluster: reachable"

echo "Checking for existing platform backups..."
BACKUP_COUNT=$(kubectl --context "${CONTEXT}" -n velero get backups \
  -l velero.io/schedule-name=platform \
  --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "  platform backups: ${BACKUP_COUNT} found"
if [ "${BACKUP_COUNT}" -eq 0 ]; then
  echo "FAIL: No platform backups found."
  echo "  Create one manually: velero backup create --from-schedule platform --wait --kubecontext ${CONTEXT}"
  exit 1
fi

echo "Checking CNPG platform cluster health..."
CNPG_PHASE=$(kubectl --context "${CONTEXT}" -n database get cluster platform \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "unknown")
if [[ "${CNPG_PHASE}" == *"healthy"* ]]; then
  echo "  CNPG cluster: healthy"
else
  echo "  WARNING: CNPG status is '${CNPG_PHASE}' -- proceeding (backup captures current state)"
fi

echo ""
echo "Preflight passed."
echo ""

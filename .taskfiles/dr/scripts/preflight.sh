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
BACKUP_COUNT=$(kubectl --context "${CONTEXT}" -n velero get backups.velero.io \
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
  echo "FAIL: CNPG cluster is not healthy (phase: ${CNPG_PHASE}). Cannot proceed."
  exit 1
fi

echo "Checking for CNPG Barman base backup..."
CNPG_BACKUP_COUNT=$(kubectl --context "${CONTEXT}" -n database \
  get backup.postgresql.cnpg.io -l cnpg.io/cluster=platform \
  -o jsonpath='{.items[?(@.status.phase=="completed")].metadata.name}' \
  2>/dev/null | wc -w | tr -d ' ')
echo "  CNPG base backups: ${CNPG_BACKUP_COUNT} completed"

if [ "${CNPG_BACKUP_COUNT}" -eq 0 ]; then
  echo ""
  echo "  WARNING: No completed CNPG base backup found."
  echo "  Without a base backup, Barman recovery will fail after rebuild."
  read -r -p "  Create a base backup now and continue? [y/N] " REPLY </dev/tty
  if [[ "${REPLY}" =~ ^[Yy]$ ]]; then
    CNPG_BACKUP_NAME="preflight-${EXERCISE_ID}"
    echo "  Creating CNPG backup: ${CNPG_BACKUP_NAME}"
    kubectl --context "${CONTEXT}" -n database apply -f - <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: ${CNPG_BACKUP_NAME}
  namespace: database
spec:
  cluster:
    name: platform
  method: barmanObjectStore
EOF
    echo "  Waiting for CNPG backup to complete (up to 30m)..."
    elapsed=0
    while true; do
      PHASE=$(kubectl --context "${CONTEXT}" -n database \
        get backup.postgresql.cnpg.io "${CNPG_BACKUP_NAME}" \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
      if [ "${PHASE}" = "completed" ]; then
        echo "  CNPG backup completed: ${CNPG_BACKUP_NAME}"
        break
      fi
      if [ "${PHASE}" = "failed" ]; then
        echo "FAIL: CNPG backup failed."
        kubectl --context "${CONTEXT}" -n database \
          describe backup.postgresql.cnpg.io "${CNPG_BACKUP_NAME}" || true
        exit 1
      fi
      if [ "${elapsed}" -ge 1800 ]; then
        echo "FAIL: CNPG backup timed out after 30m (phase: ${PHASE:-unknown})"
        exit 1
      fi
      echo "  Backup phase: ${PHASE:-pending} (${elapsed}s)"
      sleep 15
      elapsed=$((elapsed + 15))
    done
  else
    echo "FAIL: No CNPG base backup available. Cannot proceed with DR exercise."
    exit 1
  fi
fi

echo ""
echo "Preflight passed."
echo ""

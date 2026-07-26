#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  CREATING CNPG BASE BACKUP"
echo "============================================================"
echo ""

# Use fully-qualified CRD name (backups.postgresql.cnpg.io) to avoid
# the shortname collision with Longhorn's backup CRD.
BACKUP_NAME=$(kubectl --context "${CONTEXT}" -n database create -f - -o jsonpath='{.metadata.name}' <<EOF
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  generateName: ${EXERCISE_ID}-
  namespace: database
spec:
  method: barmanObjectStore
  cluster:
    name: platform
EOF
)

echo "Backup name: ${BACKUP_NAME}"
echo "Waiting for backup to complete (timeout: 20m)..."

TIMEOUT_SECONDS=1200
POLL_INTERVAL=10
ELAPSED=0

while true; do
  PHASE=$(kubectl --context "${CONTEXT}" -n database \
    get backups.postgresql.cnpg.io "${BACKUP_NAME}" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

  case "${PHASE}" in
    completed)
      echo "Backup completed: ${BACKUP_NAME}"
      echo ""
      exit 0
      ;;
    failed)
      echo "FAIL: CNPG backup failed (phase: ${PHASE})"
      kubectl --context "${CONTEXT}" -n database \
        get backups.postgresql.cnpg.io "${BACKUP_NAME}" -o yaml
      exit 1
      ;;
    "")
      echo "  [${ELAPSED}s] Backup not yet observable, waiting..."
      ;;
    *)
      echo "  [${ELAPSED}s] Backup phase: ${PHASE}"
      ;;
  esac

  if [ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]; then
    echo "FAIL: CNPG backup did not complete within ${TIMEOUT_SECONDS}s (last phase: ${PHASE})"
    kubectl --context "${CONTEXT}" -n database \
      get backups.postgresql.cnpg.io "${BACKUP_NAME}" -o yaml
    exit 1
  fi

  sleep "${POLL_INTERVAL}"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

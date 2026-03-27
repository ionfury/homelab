#!/bin/bash
set -euo pipefail

# Velero Restore Gate Script
#
# Blocks Flux health-check until all Velero Restore CRs reach a terminal state.
# Two phases:
#   1. Wait for Velero BSL to sync existing backups from S3 (120s timeout)
#   2. Poll Restore CRs until none remain in non-terminal phases
#
# Exit codes:
#   0 — All restores terminal (including Failed), or fresh cluster (no backups)
#   non-zero — Only from set -e on unexpected errors

BACKUP_SYNC_TIMEOUT="${BACKUP_SYNC_TIMEOUT:-120}"
POLL_INTERVAL="${POLL_INTERVAL:-15}"

# Phase 1: Wait for Velero to discover existing backups from S3.
# On a fresh deploy, the BackupStorageLocation needs time to sync.
echo "Phase 1: Waiting up to ${BACKUP_SYNC_TIMEOUT}s for backup discovery..."
deadline=$((SECONDS + BACKUP_SYNC_TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
  count=$(kubectl get backups.velero.io -n velero -o name 2>/dev/null | wc -l)
  if [ "$count" -gt 0 ]; then
    echo "Found ${count} backup(s) in BSL."
    break
  fi
  echo "No backups found yet, waiting... ($((deadline - SECONDS))s remaining)"
  sleep "$POLL_INTERVAL"
done

if [ "$(kubectl get backups.velero.io -n velero -o name 2>/dev/null | wc -l)" -eq 0 ]; then
  echo "No backups found after ${BACKUP_SYNC_TIMEOUT}s — assuming fresh cluster. Exiting successfully."
  exit 0
fi

# Phase 2: Wait for all Restore CRs to reach a terminal state.
echo "Phase 2: Waiting for Restore CRs to complete..."
while true; do
  restores=$(kubectl get restores.velero.io -n velero \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' 2>/dev/null)

  if [ -z "$restores" ]; then
    echo "No Restore CRs found. Exiting successfully."
    exit 0
  fi

  pending=0
  while IFS=$'\t' read -r name phase; do
    [ -z "$name" ] && continue
    case "$phase" in
      New|InProgress|WaitingForPluginOperations|WaitingForPluginOperationsPartiallyFailed|Finalizing|FinalizingPartiallyFailed)
        echo "Restore ${name} is in non-terminal phase: ${phase}"
        pending=$((pending + 1))
        ;;
      Failed|PartiallyFailed|FailedValidation)
        echo "WARNING: Restore ${name} has phase: ${phase}"
        ;;
      Completed)
        echo "Restore ${name} completed successfully."
        ;;
      "")
        echo "Restore ${name} has no phase yet (waiting for controller)."
        pending=$((pending + 1))
        ;;
      *)
        echo "Restore ${name} has unrecognized phase: ${phase} (treating as non-terminal)"
        pending=$((pending + 1))
        ;;
    esac
  done <<< "$restores"

  if [ "$pending" -eq 0 ]; then
    echo "All Restore CRs have reached terminal state."
    exit 0
  fi

  echo "Waiting for ${pending} restore(s) to complete..."
  sleep "$POLL_INTERVAL"
done

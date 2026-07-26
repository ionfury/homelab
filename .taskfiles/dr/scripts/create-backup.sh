#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  CREATING VELERO BACKUP"
echo "============================================================"
echo ""
echo "Backup name: ${EXERCISE_ID}"

velero backup create "${EXERCISE_ID}" \
  --from-schedule platform \
  --kubecontext "${CONTEXT}" \
  --wait

PHASE=$(kubectl --context "${CONTEXT}" -n velero \
  get backup.velero.io "${EXERCISE_ID}" \
  -o jsonpath='{.status.phase}')
echo "Backup phase: ${PHASE}"

if [ "${PHASE}" != "Completed" ]; then
  echo "FAIL: Backup did not complete (phase: ${PHASE})"
  velero backup describe "${EXERCISE_ID}" --kubecontext "${CONTEXT}"
  exit 1
fi

echo "Backup completed: ${EXERCISE_ID}"
echo ""

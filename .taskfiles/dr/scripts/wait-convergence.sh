#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  WAITING FOR FLUX CONVERGENCE"
echo "============================================================"
echo ""

GATE_TIMEOUT=1800   # 30m -- matches gate job activeDeadlineSeconds
KS_TIMEOUT=900      # 15m for all Kustomizations
CNPG_TIMEOUT=900    # 15m for CNPG healthy
STABILIZE_WAIT=60   # 60s post-convergence stabilization

echo "Waiting for Flux controllers to be available..."
kubectl --context "${CONTEXT}" -n flux-system wait deployment \
  --all --for=condition=Available --timeout=300s

echo "Waiting for velero-restore-gate Job to complete (up to $((GATE_TIMEOUT / 60))m)..."
elapsed=0
GATE_STATUS=""
while true; do
  GATE_STATUS=$(kubectl --context "${CONTEXT}" -n velero get job velero-restore-gate \
    -o jsonpath='{.status.conditions[?(@.type=="Complete")].status}' 2>/dev/null || echo "")
  GATE_FAILED=$(kubectl --context "${CONTEXT}" -n velero get job velero-restore-gate \
    -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")

  if [ "${GATE_STATUS}" = "True" ]; then
    echo "  Gate job complete."
    break
  fi
  if [ "${GATE_FAILED}" = "True" ]; then
    echo "FAIL: Gate job failed."
    kubectl --context "${CONTEXT}" -n velero logs job/velero-restore-gate --tail=50 || true
    exit 1
  fi
  if [ "${elapsed}" -ge "${GATE_TIMEOUT}" ]; then
    echo "FAIL: Gate job timed out after ${GATE_TIMEOUT}s"
    kubectl --context "${CONTEXT}" -n velero get restore 2>/dev/null || true
    exit 1
  fi
  echo "  Gate job pending... (${elapsed}s)"
  sleep 15
  elapsed=$((elapsed + 15))
done

echo "Waiting for critical-path Kustomizations to be Ready (up to $((KS_TIMEOUT / 60))m)..."
kubectl --context "${CONTEXT}" wait kustomizations.kustomize.toolkit.fluxcd.io \
  -n flux-system \
  --for=condition=Ready \
  --timeout="${KS_TIMEOUT}s" \
  velero-restore garage-config database-config platform-config

echo "Waiting for CNPG platform cluster to be healthy (up to $((CNPG_TIMEOUT / 60))m)..."
elapsed=0
CNPG_PHASE=""
while true; do
  CNPG_PHASE=$(kubectl --context "${CONTEXT}" -n database get cluster platform \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "not-found")
  echo "  CNPG: ${CNPG_PHASE} (${elapsed}s)"
  if [[ "${CNPG_PHASE}" == *"healthy"* ]]; then
    break
  fi
  if [ "${elapsed}" -ge "${CNPG_TIMEOUT}" ]; then
    echo "FAIL: CNPG cluster did not reach healthy state in ${CNPG_TIMEOUT}s (last phase: ${CNPG_PHASE})"
    kubectl --context "${CONTEXT}" -n database get cluster platform -o yaml | tail -30 || true
    exit 1
  fi
  sleep 15
  elapsed=$((elapsed + 15))
done

echo "Waiting ${STABILIZE_WAIT}s for stabilization before verification..."
sleep "${STABILIZE_WAIT}"

echo "Convergence complete."
echo ""

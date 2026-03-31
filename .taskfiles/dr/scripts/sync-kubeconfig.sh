#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  SYNCING KUBECONFIG"
echo "============================================================"
echo ""

SSM_PARAM="/homelab/infrastructure/clusters/${CONTEXT}/kubeconfig"
TMPKC="/tmp/kc-${CONTEXT}-dr.yaml"
MAX_SSM_WAIT=120
MAX_API_WAIT=300

echo "Waiting for kubeconfig in SSM (up to ${MAX_SSM_WAIT}s)..."
elapsed=0
while ! aws ssm get-parameter --name "${SSM_PARAM}" --with-decryption &>/dev/null; do
  if [ "${elapsed}" -ge "${MAX_SSM_WAIT}" ]; then
    echo "FAIL: Kubeconfig not available in SSM after ${MAX_SSM_WAIT}s"
    exit 1
  fi
  echo "  Waiting... (${elapsed}s)"
  sleep 10
  elapsed=$((elapsed + 10))
done

echo "Fetching kubeconfig from SSM..."
aws ssm get-parameter \
  --name "${SSM_PARAM}" \
  --with-decryption \
  --query Parameter.Value \
  --output text > "${TMPKC}"

CURRENT_CTX=$(KUBECONFIG="${TMPKC}" kubectl config current-context 2>/dev/null || echo "")
if [ -n "${CURRENT_CTX}" ] && [ "${CURRENT_CTX}" != "${CONTEXT}" ]; then
  KUBECONFIG="${TMPKC}" kubectl config rename-context "${CURRENT_CTX}" "${CONTEXT}"
fi

[ -f ~/.kube/config ] && cp ~/.kube/config ~/.kube/config.dr-bak
KUBECONFIG=~/.kube/config:"${TMPKC}" kubectl config view --flatten > /tmp/kc-merged.yaml
mv /tmp/kc-merged.yaml ~/.kube/config
chmod 0600 ~/.kube/config
rm -f "${TMPKC}"

echo "Kubeconfig merged. Waiting for API server (up to ${MAX_API_WAIT}s)..."
elapsed=0
while ! kubectl --context "${CONTEXT}" cluster-info &>/dev/null; do
  if [ "${elapsed}" -ge "${MAX_API_WAIT}" ]; then
    echo "FAIL: Dev cluster API server not reachable after ${MAX_API_WAIT}s"
    exit 1
  fi
  echo "  Waiting... (${elapsed}s)"
  sleep 10
  elapsed=$((elapsed + 10))
done

echo "Dev cluster API server reachable."
echo ""

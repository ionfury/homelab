#!/bin/bash
# Check ExternalSecret sync status for a given secret and namespace
# Usage: CONTEXT=<cluster> ./check-secret-sync.sh <name> <namespace>
# Example: CONTEXT=live ./check-secret-sync.sh lldap-secrets authelia

set -euo pipefail

NAME="${1:?Usage: $0 <externalsecret-name> <namespace>}"
NAMESPACE="${2:?Usage: $0 <externalsecret-name> <namespace>}"

echo "=== ExternalSecret Status ==="
kubectl get externalsecret "$NAME" -n "$NAMESPACE" -o wide

echo ""
echo "=== ExternalSecret Details ==="
kubectl describe externalsecret "$NAME" -n "$NAMESPACE"

echo ""
echo "=== ClusterSecretStore Health ==="
kubectl get clustersecretstore aws-ssm

echo ""
echo "=== ESO Operator Logs (last 50 lines) ==="
kubectl logs -n kube-system -l app.kubernetes.io/name=external-secrets --tail=50

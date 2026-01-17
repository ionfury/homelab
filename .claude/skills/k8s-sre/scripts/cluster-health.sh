#!/bin/bash
# Quick cluster health snapshot - READ-ONLY operations only
# Usage: ./cluster-health.sh [namespace]

set -euo pipefail

NAMESPACE="${1:-}"

echo "=== Node Status ==="
kubectl get nodes -o wide

echo ""
echo "=== Node Resources ==="
kubectl top nodes 2>/dev/null || echo "(metrics-server not available)"

if [[ -n "$NAMESPACE" ]]; then
    echo ""
    echo "=== Namespace: $NAMESPACE ==="
    kubectl get all -n "$NAMESPACE"

    echo ""
    echo "=== Recent Events in $NAMESPACE ==="
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -15
else
    echo ""
    echo "=== Problem Pods (non-Running) ==="
    kubectl get pods -A --field-selector 'status.phase!=Running,status.phase!=Succeeded' 2>/dev/null || echo "All pods healthy"

    echo ""
    echo "=== Recent Warning Events ==="
    kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' 2>/dev/null | tail -10
fi

echo ""
echo "=== PVC Status ==="
kubectl get pvc -A 2>/dev/null | grep -v "Bound" || echo "All PVCs bound"

#!/bin/bash
# Check deployment health for a newly deployed application
# Usage: ./check-deployment-health.sh <namespace> <app-name>
#
# Returns exit 0 if healthy, exit 1 if issues detected

set -euo pipefail

NAMESPACE="${1:-}"
APP_NAME="${2:-}"

if [[ -z "$NAMESPACE" || -z "$APP_NAME" ]]; then
    echo "Usage: $0 <namespace> <app-name>" >&2
    exit 1
fi

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/dev.yaml}"
export KUBECONFIG

echo "=== Deployment Health Check: $APP_NAME in $NAMESPACE ==="
echo ""

# Check pods
echo "=== Pod Status ==="
PODS=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$APP_NAME" -o json 2>/dev/null || echo '{"items":[]}')

if [[ $(echo "$PODS" | jq '.items | length') -eq 0 ]]; then
    # Try alternative label
    PODS=$(kubectl get pods -n "$NAMESPACE" -l "app=$APP_NAME" -o json 2>/dev/null || echo '{"items":[]}')
fi

POD_COUNT=$(echo "$PODS" | jq '.items | length')

if [[ "$POD_COUNT" -eq 0 ]]; then
    echo "ERROR: No pods found for $APP_NAME in $NAMESPACE"
    echo "Labels tried: app.kubernetes.io/name=$APP_NAME, app=$APP_NAME"
    exit 1
fi

echo "Found $POD_COUNT pod(s)"
echo ""

# Check each pod
HEALTHY=true
echo "$PODS" | jq -r '.items[] | "\(.metadata.name) \(.status.phase) \(.status.containerStatuses // [] | map(.ready) | all)"' | while read -r name phase ready; do
    if [[ "$phase" != "Running" ]]; then
        echo "  $name: $phase (NOT HEALTHY)"
        HEALTHY=false
    elif [[ "$ready" != "true" ]]; then
        echo "  $name: $phase but containers not ready (NOT HEALTHY)"
        HEALTHY=false
    else
        echo "  $name: $phase (HEALTHY)"
    fi
done

# Check for CrashLoopBackOff
CRASH_LOOPS=$(echo "$PODS" | jq -r '.items[].status.containerStatuses[]? | select(.state.waiting.reason == "CrashLoopBackOff") | .name' 2>/dev/null || true)
if [[ -n "$CRASH_LOOPS" ]]; then
    echo ""
    echo "ERROR: CrashLoopBackOff detected:"
    echo "$CRASH_LOOPS"
    echo ""
    echo "=== Recent Logs ==="
    FIRST_POD=$(echo "$PODS" | jq -r '.items[0].metadata.name')
    kubectl logs -n "$NAMESPACE" "$FIRST_POD" --tail=50 2>/dev/null || echo "(logs unavailable)"
    HEALTHY=false
fi

# Check for ImagePullBackOff
IMAGE_PULLS=$(echo "$PODS" | jq -r '.items[].status.containerStatuses[]? | select(.state.waiting.reason == "ImagePullBackOff" or .state.waiting.reason == "ErrImagePull") | .name' 2>/dev/null || true)
if [[ -n "$IMAGE_PULLS" ]]; then
    echo ""
    echo "ERROR: Image pull issues detected:"
    echo "$IMAGE_PULLS"
    HEALTHY=false
fi

# Check for OOMKilled
OOM=$(echo "$PODS" | jq -r '.items[].status.containerStatuses[]? | select(.lastState.terminated.reason == "OOMKilled") | .name' 2>/dev/null || true)
if [[ -n "$OOM" ]]; then
    echo ""
    echo "WARNING: OOMKilled detected (container may need more memory):"
    echo "$OOM"
fi

# Check events
echo ""
echo "=== Recent Events ==="
kubectl get events -n "$NAMESPACE" --field-selector "involvedObject.name=$APP_NAME" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || echo "(no events)"

# Check services
echo ""
echo "=== Services ==="
kubectl get svc -n "$NAMESPACE" -l "app.kubernetes.io/name=$APP_NAME" 2>/dev/null || \
kubectl get svc -n "$NAMESPACE" -l "app=$APP_NAME" 2>/dev/null || \
echo "(no services found with standard labels)"

# Summary
echo ""
echo "=== Summary ==="
if [[ "$HEALTHY" == "true" ]]; then
    echo "Deployment appears healthy"
    exit 0
else
    echo "Issues detected - review above output"
    exit 1
fi

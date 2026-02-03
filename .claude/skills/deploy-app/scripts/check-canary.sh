#!/bin/bash
# Check canary health check status for an application
# Usage: ./check-canary.sh <app-name>
#
# Requires kubectl access to the cluster

set -euo pipefail

APP_NAME="${1:-}"

if [[ -z "$APP_NAME" ]]; then
    echo "Usage: $0 <app-name>" >&2
    exit 1
fi

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/dev.yaml}"
export KUBECONFIG

echo "=== Canary Health Check: $APP_NAME ==="
echo ""

# Look for canary resources
CANARY_NAME="http-check-$APP_NAME"

# Check if canary exists
if ! kubectl get canary "$CANARY_NAME" -n default >/dev/null 2>&1; then
    # Try finding in other namespaces
    CANARY=$(kubectl get canary -A -o json 2>/dev/null | jq -r --arg name "$CANARY_NAME" \
        '.items[] | select(.metadata.name == $name) | "\(.metadata.namespace)/\(.metadata.name)"' | head -1)

    if [[ -z "$CANARY" ]]; then
        # Try partial match
        CANARY=$(kubectl get canary -A -o json 2>/dev/null | jq -r --arg app "$APP_NAME" \
            '.items[] | select(.metadata.name | contains($app)) | "\(.metadata.namespace)/\(.metadata.name)"' | head -1)
    fi

    if [[ -z "$CANARY" ]]; then
        echo "No canary found for $APP_NAME"
        echo ""
        echo "Expected canary name: $CANARY_NAME"
        echo ""
        echo "Available canaries:"
        kubectl get canary -A 2>/dev/null || echo "(none found)"
        exit 0  # Not an error if canary doesn't exist
    fi

    NAMESPACE="${CANARY%%/*}"
    CANARY_NAME="${CANARY##*/}"
else
    NAMESPACE="default"
fi

echo "Found canary: $NAMESPACE/$CANARY_NAME"
echo ""

# Get canary status
CANARY_JSON=$(kubectl get canary "$CANARY_NAME" -n "$NAMESPACE" -o json 2>/dev/null)

# Extract status
STATUS=$(echo "$CANARY_JSON" | jq -r '.status.status // "unknown"')
MESSAGE=$(echo "$CANARY_JSON" | jq -r '.status.message // "No message"')
LAST_RUN=$(echo "$CANARY_JSON" | jq -r '.status.lastRuntime // "Never"')
UPTIME=$(echo "$CANARY_JSON" | jq -r '.status.uptime1h // "N/A"')

echo "Status: $STATUS"
echo "Message: $MESSAGE"
echo "Last Run: $LAST_RUN"
echo "Uptime (1h): $UPTIME"
echo ""

# Check individual checks
echo "=== Check Results ==="
echo "$CANARY_JSON" | jq -r '.status.checkStatuses // [] | .[] | "\(.name): \(.status) (duration: \(.duration)ms)"' 2>/dev/null || echo "(no check statuses)"

# Determine exit code
case "$STATUS" in
    "Passed"|"Healthy")
        echo ""
        echo "=== Canary PASSED ==="
        exit 0
        ;;
    "Failed"|"Unhealthy")
        echo ""
        echo "=== Canary FAILED ==="
        echo ""
        echo "Check the canary configuration and target endpoint"
        exit 1
        ;;
    *)
        echo ""
        echo "=== Canary status: $STATUS ==="
        echo "May need more time to run first check"
        exit 0
        ;;
esac

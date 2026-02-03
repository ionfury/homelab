#!/bin/bash
# Check for firing alerts in Prometheus
# Usage: ./check-alerts.sh [--baseline <file>]
#
# Without baseline: Shows all firing alerts
# With baseline: Shows only NEW alerts since baseline was captured
#
# To capture a baseline before deployment:
#   ./check-alerts.sh > /tmp/alerts-baseline.txt
#
# Then after deployment:
#   ./check-alerts.sh --baseline /tmp/alerts-baseline.txt

set -euo pipefail

BASELINE_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --baseline)
            BASELINE_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

# Check if Prometheus is accessible
if ! curl -sf "$PROMETHEUS_URL/-/ready" >/dev/null 2>&1; then
    echo "ERROR: Prometheus not accessible at $PROMETHEUS_URL"
    echo ""
    echo "Start a port-forward:"
    echo "  kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
    exit 1
fi

echo "=== Alert Status Check ==="
echo "Using Prometheus at: $PROMETHEUS_URL"
echo ""

# Get all alerts
ALERTS=$(curl -sf "$PROMETHEUS_URL/api/v1/alerts" 2>/dev/null || echo '{"data":{"alerts":[]}}')

# Extract firing alerts
FIRING=$(echo "$ALERTS" | jq -r '[.data.alerts[] | select(.state == "firing")]')
FIRING_COUNT=$(echo "$FIRING" | jq 'length')

# Extract pending alerts
PENDING=$(echo "$ALERTS" | jq -r '[.data.alerts[] | select(.state == "pending")]')
PENDING_COUNT=$(echo "$PENDING" | jq 'length')

echo "Firing alerts: $FIRING_COUNT"
echo "Pending alerts: $PENDING_COUNT"
echo ""

if [[ "$FIRING_COUNT" -gt 0 ]]; then
    # Get alert names for comparison
    CURRENT_ALERTS=$(echo "$FIRING" | jq -r '.[].labels.alertname' | sort)

    if [[ -n "$BASELINE_FILE" && -f "$BASELINE_FILE" ]]; then
        # Compare against baseline
        NEW_ALERTS=$(comm -13 <(cat "$BASELINE_FILE") <(echo "$CURRENT_ALERTS"))

        if [[ -n "$NEW_ALERTS" ]]; then
            echo "=== NEW Firing Alerts (since baseline) ==="
            echo "$NEW_ALERTS" | while read -r alert; do
                echo "$FIRING" | jq -r --arg name "$alert" \
                    '.[] | select(.labels.alertname == $name) | "[\(.labels.severity // "unknown")] \(.labels.alertname): \(.annotations.summary // .annotations.description // "No description")"'
            done
            echo ""
            echo "WARNING: New alerts detected after deployment"
            exit 1
        else
            echo "=== No NEW alerts since baseline ==="
            echo "All $FIRING_COUNT firing alerts existed before deployment"
            exit 0
        fi
    else
        # No baseline, just show all firing alerts
        echo "=== Firing Alerts ==="
        echo "$FIRING" | jq -r '.[] | "[\(.labels.severity // "unknown")] \(.labels.alertname): \(.annotations.summary // .annotations.description // "No description")"'

        # Output alert names for baseline capture
        echo ""
        echo "# Alert names (for baseline comparison):"
        echo "$CURRENT_ALERTS"
    fi
fi

if [[ "$PENDING_COUNT" -gt 0 ]]; then
    echo ""
    echo "=== Pending Alerts (may fire soon) ==="
    echo "$PENDING" | jq -r '.[] | "[\(.labels.severity // "unknown")] \(.labels.alertname): \(.annotations.summary // .annotations.description // "No description")"'
fi

if [[ "$FIRING_COUNT" -eq 0 ]]; then
    echo "=== No firing alerts ==="
    exit 0
fi

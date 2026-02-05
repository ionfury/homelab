#!/bin/bash
# Check if ServiceMonitor is being scraped by Prometheus
# Usage: ./check-servicemonitor.sh <job-name>
#
# Requires port-forward to Prometheus or PROMETHEUS_URL environment variable
# Run: kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

set -euo pipefail

JOB_NAME="${1:-}"

if [[ -z "$JOB_NAME" ]]; then
    echo "Usage: $0 <job-name>" >&2
    exit 1
fi

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

echo "=== ServiceMonitor Check: $JOB_NAME ==="
echo "Using Prometheus at: $PROMETHEUS_URL"
echo ""

# Check if Prometheus is accessible
if ! curl -sf "$PROMETHEUS_URL/-/ready" >/dev/null 2>&1; then
    echo "ERROR: Prometheus not accessible at $PROMETHEUS_URL"
    echo ""
    echo "Start a port-forward:"
    echo "  kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090"
    exit 1
fi

# Query active targets
echo "=== Searching for job '$JOB_NAME' in active targets ==="
TARGETS=$(curl -sf "$PROMETHEUS_URL/api/v1/targets" 2>/dev/null || echo '{"data":{"activeTargets":[]}}')

# Search for matching targets (case-insensitive partial match)
MATCHES=$(echo "$TARGETS" | jq -r --arg job "$JOB_NAME" \
    '[.data.activeTargets[] | select(.labels.job | ascii_downcase | contains($job | ascii_downcase))]')

MATCH_COUNT=$(echo "$MATCHES" | jq 'length')

if [[ "$MATCH_COUNT" -eq 0 ]]; then
    echo "No targets found matching job '$JOB_NAME'"
    echo ""
    echo "=== Available jobs ==="
    echo "$TARGETS" | jq -r '.data.activeTargets[].labels.job' | sort -u | head -30
    echo ""
    echo "Possible reasons:"
    echo "  1. ServiceMonitor not created (check helm values serviceMonitor.enabled)"
    echo "  2. ServiceMonitor labels don't match Prometheus selector"
    echo "  3. Target namespace not being scraped"
    echo "  4. Prometheus hasn't reloaded yet (wait 30-60s)"
    exit 1
fi

echo "Found $MATCH_COUNT target(s):"
echo ""

# Show target details
echo "$MATCHES" | jq -r '.[] | "Job: \(.labels.job)\n  Instance: \(.labels.instance)\n  State: \(.health)\n  Last Scrape: \(.lastScrape)\n  Scrape Duration: \(.lastScrapeDuration)s\n"'

# Check health
UNHEALTHY=$(echo "$MATCHES" | jq '[.[] | select(.health != "up")] | length')
if [[ "$UNHEALTHY" -gt 0 ]]; then
    echo "WARNING: $UNHEALTHY target(s) not healthy"
    echo ""
    echo "Unhealthy targets:"
    echo "$MATCHES" | jq -r '.[] | select(.health != "up") | "  \(.labels.instance): \(.lastError)"'
    exit 1
fi

echo "=== All targets healthy ==="
exit 0

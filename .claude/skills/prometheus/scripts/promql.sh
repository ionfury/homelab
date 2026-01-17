#!/bin/bash
# Query Prometheus API - supports instant, range, alerts, and rules queries
# Usage: ./promql.sh <query|alerts|rules|series|labels|health> [options]
#
# Examples:
#   ./promql.sh query 'up'
#   ./promql.sh query 'rate(node_cpu_seconds_total[5m])' --time 2024-01-01T00:00:00Z
#   ./promql.sh range 'up' --start 1h --step 15s
#   ./promql.sh alerts
#   ./promql.sh alerts --firing
#   ./promql.sh rules
#   ./promql.sh series '{job="node-exporter"}'
#   ./promql.sh labels job
#   ./promql.sh health

set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  query <promql>      Instant query at current time (or --time)
  range <promql>      Range query over time period
  alerts             List all alerts (use --firing for active only)
  rules              List alerting and recording rules
  series <selector>   Find time series matching selector
  labels [name]       List label names, or values for a label
  health             Check Prometheus health and readiness

Query Options:
  --time <timestamp>  Evaluation time for instant query (RFC3339 or Unix)

Range Options:
  --start <duration>  Start time as duration ago (e.g., 1h, 30m, 7d) [default: 1h]
  --end <duration>    End time as duration ago [default: now]
  --step <duration>   Query resolution step [default: 15s]

Alert Options:
  --firing           Show only firing alerts

Output Options:
  --raw              Output raw JSON without jq formatting
  --verbose          Show full response including status

Environment:
  PROMETHEUS_URL     Prometheus base URL [default: http://localhost:9090]

Examples:
  # Current CPU usage across all nodes
  $(basename "$0") query 'avg(1 - rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100'

  # Memory usage over last hour
  $(basename "$0") range '(1 - node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes) * 100' --start 1h --step 1m

  # All firing alerts
  $(basename "$0") alerts --firing

  # Find all node-exporter metrics
  $(basename "$0") series '{job="node-exporter"}'
EOF
    exit 1
}

# Parse duration to seconds (1h -> 3600, 30m -> 1800, 7d -> 604800)
duration_to_seconds() {
    local duration="$1"
    local num="${duration%[smhdw]}"
    local unit="${duration: -1}"

    case "$unit" in
        s) echo "$num" ;;
        m) echo $((num * 60)) ;;
        h) echo $((num * 3600)) ;;
        d) echo $((num * 86400)) ;;
        w) echo $((num * 604800)) ;;
        *) echo "$duration" ;;  # Assume already seconds
    esac
}

# URL encode a string
urlencode() {
    local string="$1"
    python3 -c "import urllib.parse; print(urllib.parse.quote('''$string''', safe=''))"
}

# Make API request
api_request() {
    local endpoint="$1"
    local raw="${2:-false}"
    local verbose="${3:-false}"

    local response
    response=$(curl -s -f "$PROMETHEUS_URL/api/v1/$endpoint") || {
        echo "Error: Failed to query $PROMETHEUS_URL/api/v1/$endpoint" >&2
        exit 1
    }

    if [[ "$raw" == "true" ]]; then
        echo "$response"
    elif [[ "$verbose" == "true" ]]; then
        echo "$response" | jq .
    else
        echo "$response" | jq -r '.data // .status'
    fi
}

cmd_query() {
    local query=""
    local time=""
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --time) time="$2"; shift 2 ;;
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) query="$1"; shift ;;
        esac
    done

    [[ -z "$query" ]] && { echo "Error: Query required" >&2; exit 1; }

    local endpoint="query?query=$(urlencode "$query")"
    [[ -n "$time" ]] && endpoint+="&time=$(urlencode "$time")"

    api_request "$endpoint" "$raw" "$verbose"
}

cmd_range() {
    local query=""
    local start="1h"
    local end=""
    local step="15s"
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start) start="$2"; shift 2 ;;
            --end) end="$2"; shift 2 ;;
            --step) step="$2"; shift 2 ;;
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) query="$1"; shift ;;
        esac
    done

    [[ -z "$query" ]] && { echo "Error: Query required" >&2; exit 1; }

    local now
    now=$(date +%s)
    local start_ts=$((now - $(duration_to_seconds "$start")))
    local end_ts="$now"
    [[ -n "$end" ]] && end_ts=$((now - $(duration_to_seconds "$end")))

    local endpoint="query_range?query=$(urlencode "$query")&start=$start_ts&end=$end_ts&step=$step"

    api_request "$endpoint" "$raw" "$verbose"
}

cmd_alerts() {
    local firing_only="false"
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --firing) firing_only="true"; shift ;;
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) shift ;;
        esac
    done

    local response
    response=$(curl -s -f "$PROMETHEUS_URL/api/v1/alerts") || {
        echo "Error: Failed to query alerts" >&2
        exit 1
    }

    if [[ "$raw" == "true" ]]; then
        echo "$response"
    elif [[ "$firing_only" == "true" ]]; then
        echo "$response" | jq -r '.data.alerts[] | select(.state == "firing") | "\(.labels.alertname) [\(.labels.severity // "unknown")] - \(.annotations.summary // .annotations.description // "No description")"'
    elif [[ "$verbose" == "true" ]]; then
        echo "$response" | jq .
    else
        echo "$response" | jq -r '.data.alerts[] | "\(.state | ascii_upcase): \(.labels.alertname) [\(.labels.severity // "unknown")]"'
    fi
}

cmd_rules() {
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) shift ;;
        esac
    done

    local response
    response=$(curl -s -f "$PROMETHEUS_URL/api/v1/rules") || {
        echo "Error: Failed to query rules" >&2
        exit 1
    }

    if [[ "$raw" == "true" ]]; then
        echo "$response"
    elif [[ "$verbose" == "true" ]]; then
        echo "$response" | jq .
    else
        echo "$response" | jq -r '.data.groups[].rules[] | "\(.type): \(.name)"'
    fi
}

cmd_series() {
    local selector=""
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) selector="$1"; shift ;;
        esac
    done

    [[ -z "$selector" ]] && { echo "Error: Selector required" >&2; exit 1; }

    api_request "series?match[]=$(urlencode "$selector")" "$raw" "$verbose"
}

cmd_labels() {
    local label_name=""
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) label_name="$1"; shift ;;
        esac
    done

    local endpoint="labels"
    [[ -n "$label_name" ]] && endpoint="label/$label_name/values"

    api_request "$endpoint" "$raw" "$verbose"
}

cmd_health() {
    echo "=== Prometheus Health ==="
    echo -n "Ready: "
    curl -fsS "$PROMETHEUS_URL/-/ready" >/dev/null 2>&1 && echo "OK" || echo "FAILED"

    echo -n "Healthy: "
    curl -fsS "$PROMETHEUS_URL/-/healthy" >/dev/null 2>&1 && echo "OK" || echo "FAILED"

    echo ""
    echo "=== Build Info ==="
    curl -s "$PROMETHEUS_URL/api/v1/status/buildinfo" | jq -r '.data | "Version: \(.version)\nBranch: \(.branch)\nRevision: \(.revision[0:8])"'

    echo ""
    echo "=== Runtime Info ==="
    curl -s "$PROMETHEUS_URL/api/v1/status/runtimeinfo" | jq -r '.data | "Storage Retention: \(.storageRetention)\nGoroutines: \(.goroutines)\nReload Config Success: \(.reloadConfigSuccess)"'
}

# Main
[[ $# -eq 0 ]] && usage

command="$1"
shift

case "$command" in
    query) cmd_query "$@" ;;
    range) cmd_range "$@" ;;
    alerts) cmd_alerts "$@" ;;
    rules) cmd_rules "$@" ;;
    series) cmd_series "$@" ;;
    labels) cmd_labels "$@" ;;
    health) cmd_health ;;
    help|--help|-h) usage ;;
    *) echo "Unknown command: $command" >&2; usage ;;
esac

#!/bin/bash
# Query Loki API - supports instant, range, tail, labels, series, and health queries
# Usage: ./logql.sh <query|range|tail|labels|series|health> [options]
#
# Examples:
#   ./logql.sh query 'rate({namespace="monitoring"}[5m])'
#   ./logql.sh range '{namespace="monitoring"}' --start 1h --step 1m --limit 50
#   ./logql.sh tail '{namespace="flux-system"}' --since 15m
#   ./logql.sh labels
#   ./logql.sh labels namespace
#   ./logql.sh series '{namespace="monitoring"}'
#   ./logql.sh health

set -euo pipefail

LOKI_URL="${LOKI_URL:-http://localhost:3100}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  query <logql>      Instant query (metric aggregations or log snapshot)
  range <logql>      Range query over time period
  tail <logql>       Recent logs (shorthand for range with --since)
  labels [name]      List label names, or values for a label
  series <selector>  Find log streams matching selector
  health             Check Loki health and readiness

Query Options:
  --time <timestamp>  Evaluation time for instant query (RFC3339 or Unix)
  --limit <n>         Maximum log lines to return [default: 100]
  --direction <dir>   Sort order: forward or backward [default: backward]

Range Options:
  --start <duration>  Start time as duration ago (e.g., 1h, 30m, 7d) [default: 1h]
  --end <duration>    End time as duration ago [default: now]
  --step <duration>   Query resolution step [default: 15s]
  --limit <n>         Maximum log lines to return [default: 100]
  --direction <dir>   Sort order: forward or backward [default: backward]

Tail Options:
  --since <duration>  How far back to look (e.g., 5m, 15m, 1h) [default: 15m]
  --limit <n>         Maximum log lines to return [default: 100]
  --direction <dir>   Sort order: forward or backward [default: backward]

Series Options:
  --start <duration>  Start time as duration ago [default: 1h]
  --end <duration>    End time as duration ago [default: now]

Output Options:
  --raw              Output raw JSON without formatting
  --verbose          Show full response including status

Environment:
  LOKI_URL           Loki base URL [default: http://localhost:3100]

Examples:
  # Recent errors in a namespace
  $(basename "$0") tail '{namespace="database"} |= "error"' --since 30m

  # Error rate per namespace
  $(basename "$0") query 'sum by(namespace) (rate({namespace=~".+"} |= "error" [5m]))'

  # Range query with custom window
  $(basename "$0") range '{namespace="monitoring"}' --start 2h --step 30s --limit 50

  # Kubernetes warning events
  $(basename "$0") tail '{job="integrations/kubernetes/eventhandler"} |= "Warning"' --since 1h

  # Discover labels
  $(basename "$0") labels namespace
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

# URL encode a string safely using python3 sys.argv (no shell injection)
urlencode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$1"
}

# Format Loki query results based on resultType
format_response() {
    local response="$1"
    local raw="$2"
    local verbose="$3"

    if [[ "$raw" == "true" ]]; then
        echo "$response"
        return
    fi

    if [[ "$verbose" == "true" ]]; then
        echo "$response" | jq .
        return
    fi

    local result_type
    result_type=$(echo "$response" | jq -r '.data.resultType // empty' 2>/dev/null)

    case "$result_type" in
        streams)
            format_streams "$response"
            ;;
        matrix)
            format_matrix "$response"
            ;;
        vector)
            format_vector "$response"
            ;;
        *)
            # Fallback: print data or status
            echo "$response" | jq -r '.data // .status'
            ;;
    esac
}

# Format stream results as: TIMESTAMP [labels] LOG_LINE
format_streams() {
    local response="$1"
    echo "$response" | jq -r '
        .data.result[] |
        .stream as $labels |
        .values[] |
        (.[0] | tonumber / 1000000000 | strftime("%Y-%m-%d %H:%M:%S")) as $ts |
        .[1] as $line |
        ($labels | to_entries | map("\(.key)=\(.value)") | join(",")) as $lbl |
        "\($ts) [\($lbl)] \($line)"
    ' 2>/dev/null || echo "$response" | jq -r '.data // .status'
}

# Format matrix results (metric queries over time)
format_matrix() {
    local response="$1"
    echo "$response" | jq -r '
        .data.result[] |
        (.metric | to_entries | map("\(.key)=\(.value)") | join(",")) as $metric |
        "--- \($metric) ---",
        (.values[] | "\(.[0] | strftime("%Y-%m-%d %H:%M:%S")) \(.[1])")
    ' 2>/dev/null || echo "$response" | jq -r '.data // .status'
}

# Format vector results (instant metric queries)
format_vector() {
    local response="$1"
    echo "$response" | jq -r '
        .data.result[] |
        (.metric | to_entries | map("\(.key)=\(.value)") | join(",")) as $metric |
        "\($metric): \(.value[1])"
    ' 2>/dev/null || echo "$response" | jq -r '.data // .status'
}

# Make API request to Loki
api_request() {
    local endpoint="$1"

    local response
    response=$(curl -s -f "${LOKI_URL}/loki/api/v1/${endpoint}") || {
        echo "Error: Failed to query ${LOKI_URL}/loki/api/v1/${endpoint}" >&2
        echo "Is Loki reachable? Try: curl -s ${LOKI_URL}/ready" >&2
        exit 1
    }

    echo "$response"
}

cmd_query() {
    local query=""
    local time=""
    local limit="100"
    local direction="backward"
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --time) time="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            --direction) direction="$2"; shift 2 ;;
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) query="$1"; shift ;;
        esac
    done

    [[ -z "$query" ]] && { echo "Error: Query required" >&2; exit 1; }

    local endpoint="query?query=$(urlencode "$query")&limit=${limit}&direction=${direction}"
    [[ -n "$time" ]] && endpoint+="&time=$(urlencode "$time")"

    local response
    response=$(api_request "$endpoint")
    format_response "$response" "$raw" "$verbose"
}

cmd_range() {
    local query=""
    local start="1h"
    local end=""
    local step="15s"
    local limit="100"
    local direction="backward"
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start) start="$2"; shift 2 ;;
            --end) end="$2"; shift 2 ;;
            --step) step="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            --direction) direction="$2"; shift 2 ;;
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

    local endpoint="query_range?query=$(urlencode "$query")&start=${start_ts}&end=${end_ts}&step=${step}&limit=${limit}&direction=${direction}"

    local response
    response=$(api_request "$endpoint")
    format_response "$response" "$raw" "$verbose"
}

cmd_tail() {
    local query=""
    local since="15m"
    local limit="100"
    local direction="backward"
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --since) since="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            --direction) direction="$2"; shift 2 ;;
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) query="$1"; shift ;;
        esac
    done

    [[ -z "$query" ]] && { echo "Error: Query required" >&2; exit 1; }

    local now
    now=$(date +%s)
    local start_ts=$((now - $(duration_to_seconds "$since")))

    local endpoint="query_range?query=$(urlencode "$query")&start=${start_ts}&end=${now}&limit=${limit}&direction=${direction}"

    local response
    response=$(api_request "$endpoint")
    format_response "$response" "$raw" "$verbose"
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
    [[ -n "$label_name" ]] && endpoint="label/${label_name}/values"

    local response
    response=$(api_request "$endpoint")

    if [[ "$raw" == "true" ]]; then
        echo "$response"
    elif [[ "$verbose" == "true" ]]; then
        echo "$response" | jq .
    else
        echo "$response" | jq -r '.data[]'
    fi
}

cmd_series() {
    local selector=""
    local start="1h"
    local end=""
    local raw="false"
    local verbose="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start) start="$2"; shift 2 ;;
            --end) end="$2"; shift 2 ;;
            --raw) raw="true"; shift ;;
            --verbose) verbose="true"; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) selector="$1"; shift ;;
        esac
    done

    [[ -z "$selector" ]] && { echo "Error: Selector required (e.g., '{namespace=\"monitoring\"}')" >&2; exit 1; }

    local now
    now=$(date +%s)
    local start_ts=$((now - $(duration_to_seconds "$start")))
    local end_ts="$now"
    [[ -n "$end" ]] && end_ts=$((now - $(duration_to_seconds "$end")))

    local endpoint="series?match[]=$(urlencode "$selector")&start=${start_ts}&end=${end_ts}"

    local response
    response=$(api_request "$endpoint")

    if [[ "$raw" == "true" ]]; then
        echo "$response"
    elif [[ "$verbose" == "true" ]]; then
        echo "$response" | jq .
    else
        echo "$response" | jq -r '.data[] | to_entries | map("\(.key)=\(.value)") | join(", ")'
    fi
}

cmd_health() {
    echo "=== Loki Health ==="
    echo -n "Ready: "
    curl -fsS "${LOKI_URL}/ready" >/dev/null 2>&1 && echo "OK" || echo "FAILED"

    echo ""
    echo "=== Build Info ==="
    curl -s "${LOKI_URL}/loki/api/v1/status/buildinfo" | jq -r '.data // . | "Version: \(.version // "unknown")\nRevision: \(.revision // "unknown" | .[0:8])"' 2>/dev/null || echo "Build info unavailable"

    echo ""
    echo "=== Ring Status ==="
    echo -n "Ingester ring: "
    curl -fsS "${LOKI_URL}/ring" >/dev/null 2>&1 && echo "OK" || echo "UNAVAILABLE"
}

# Main
[[ $# -eq 0 ]] && usage

command="$1"
shift

case "$command" in
    query) cmd_query "$@" ;;
    range) cmd_range "$@" ;;
    tail) cmd_tail "$@" ;;
    labels) cmd_labels "$@" ;;
    series) cmd_series "$@" ;;
    health) cmd_health ;;
    help|--help|-h) usage ;;
    *) echo "Unknown command: $command" >&2; usage ;;
esac

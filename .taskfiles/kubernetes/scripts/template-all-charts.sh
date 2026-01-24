#!/usr/bin/env bash
set -euo pipefail

# Description: Templates all Helm charts defined in helm-charts.yaml
# Inputs:
#   - CHARTS_DIR: Path to chart values files
#   - HELM_CHARTS_FILE: Path to helm-charts.yaml
#   - EXPANDED_DIR: Output directory for templated charts
#   - cluster_name, cluster_pod_subnet, internal_domain, external_domain: Flux substitution vars
#   - default_replica_count, garage_data_volume_size, garage_meta_volume_size, loki_volume_size, prometheus_volume_size: Flux vars

# Parse helm-charts.yaml to get chart definitions
charts_json=$(yq '.spec.inputs' "$HELM_CHARTS_FILE" -o=json)

# Track added repos: URL -> repo_name mapping
repo_mapping_file=$(mktemp)
trap "rm -f $repo_mapping_file" EXIT

# Pre-add all HTTP repos (use sanitized URL as repo name for consistency)
echo "$charts_json" | jq -r '.[] | select(.chart.url | startswith("oci://") | not) | .chart.url' | sort -u | while read -r chart_url; do
  repo_name=$(echo "$chart_url" | sed 's|https://||; s|http://||; s|[./:-]|_|g')
  helm repo add "$repo_name" "$chart_url" 2>/dev/null || true
  echo "${chart_url}|${repo_name}" >> "$repo_mapping_file"
done
helm repo update 2>/dev/null || true

# Template each chart
chart_count=$(echo "$charts_json" | jq -r '. | length')
echo ""
echo "Templating $chart_count charts..."
echo ""

for chart_name in $(echo "$charts_json" | jq -r '.[].name'); do
  chart_info=$(echo "$charts_json" | jq -r ".[] | select(.name == \"$chart_name\")")
  chart_helm_name=$(echo "$chart_info" | jq -r '.chart.name')
  chart_version=$(echo "$chart_info" | jq -r '.chart.version')
  chart_url=$(echo "$chart_info" | jq -r '.chart.url')

  # Substitute variables in values file
  values_file="${CHARTS_DIR}/${chart_name}.yaml"
  tmp_values="/tmp/${chart_name}-values.yaml"
  envsubst < "$values_file" > "$tmp_values"

  # Handle OCI vs HTTP registries
  case "$chart_url" in
    oci://*)
      echo "Templating (OCI): $chart_name"
      if helm template "$chart_name" "${chart_url}/${chart_helm_name}" \
        --version "$chart_version" \
        --values "$tmp_values" \
        --namespace test > "${EXPANDED_DIR}/helm/${chart_name}.yaml"; then
        echo "  $chart_name"
      else
        echo "  $chart_name failed to template"
        exit 1
      fi
      ;;
    *)
      repo_name=$(grep "^${chart_url}|" "$repo_mapping_file" | cut -d'|' -f2)
      echo "Templating (HTTP): $chart_name"
      if helm template "$chart_name" "$repo_name/$chart_helm_name" \
        --version "$chart_version" \
        --values "$tmp_values" \
        --namespace test > "${EXPANDED_DIR}/helm/${chart_name}.yaml"; then
        echo "  $chart_name"
      else
        echo "  $chart_name failed to template"
        exit 1
      fi
      ;;
  esac
done

echo ""
echo "Successfully templated $chart_count charts"

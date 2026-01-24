#!/usr/bin/env bash
set -euo pipefail

# Description: Substitutes cluster variables in all manifests
# Inputs:
#   - CLUSTER_VARS: Path to cluster variables file
#   - MANIFESTS_DIR: Directory containing manifests to process

# Source cluster variables
set -a
# shellcheck source=/dev/null
source "$CLUSTER_VARS"
set +a

# Substitute variables in all manifests
for manifest in "$MANIFESTS_DIR"/*.yaml; do
  envsubst < "$manifest" > "${manifest}.tmp"
  mv "${manifest}.tmp" "$manifest"
done

# Fix StorageClass parameters to be strings (envsubst produces unquoted numbers)
for manifest in "$MANIFESTS_DIR"/*.yaml; do
  yq -i '(select(.kind == "StorageClass") | .parameters.numberOfReplicas) |= . tag = "!!str"' "$manifest"
done

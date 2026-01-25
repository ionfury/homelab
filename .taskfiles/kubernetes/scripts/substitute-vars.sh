#!/usr/bin/env bash
set -euo pipefail

# Description: Substitutes cluster and version variables in all manifests
# Inputs:
#   - CLUSTER_VARS: Path to cluster variables file
#   - VERSION_VARS: Path to version variables file
#   - MANIFESTS_DIR: Directory containing manifests to process

# Source cluster and version variables
set -a
# shellcheck source=/dev/null
source "$CLUSTER_VARS"
# shellcheck source=/dev/null
source "$VERSION_VARS"
set +a

# Function to substitute ${var:-default} patterns using bash variable lookup
substitute_with_defaults() {
  local input="$1"
  local output

  # Process ${var:-default} patterns - replace with variable value or default
  # Uses perl for portable regex with lookbehind/lookahead
  output=$(perl -pe 's/\$\{([a-zA-Z_][a-zA-Z0-9_]*):-([^}]*)\}/
    my $var = $1;
    my $default = $2;
    my $val = $ENV{$var};
    defined($val) && $val ne "" ? $val : $default;
  /gex' <<< "$input")

  echo "$output"
}

# Substitute variables in all manifests
for manifest in "$MANIFESTS_DIR"/*.yaml; do
  content=$(cat "$manifest")

  # First, expand ${var:-default} patterns
  content=$(substitute_with_defaults "$content")

  # Then use envsubst for remaining simple ${VAR} patterns
  echo "$content" | envsubst > "${manifest}.tmp"
  mv "${manifest}.tmp" "$manifest"
done

# Fix StorageClass parameters to be strings (envsubst produces unquoted numbers)
for manifest in "$MANIFESTS_DIR"/*.yaml; do
  yq -i '(select(.kind == "StorageClass") | .parameters.numberOfReplicas) |= . tag = "!!str"' "$manifest"
done

#!/usr/bin/env bash
set -euo pipefail

# Description: Builds all kustomize manifests from kubernetes/platform/config
# Inputs:
#   - MANIFESTS_DIR: Output directory for built manifests
#   - PLATFORM_DIR: Path to kubernetes/platform directory

find "$PLATFORM_DIR/config" -name "kustomization.yaml" -exec dirname {} \; | while read -r dir; do
  name=$(echo "$dir" | sed "s|$PLATFORM_DIR/config/||; s|/|-|g")
  echo "Building kustomization: $dir"
  kustomize build "$dir" > "$MANIFESTS_DIR/${name}.yaml"
done

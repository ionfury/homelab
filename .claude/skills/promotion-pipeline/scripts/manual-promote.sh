#!/usr/bin/env bash
# Manual OCI artifact promotion
# Use when automatic promotion (tag-validated-artifact.yaml) has failed.
#
# Usage:
#   manual-promote.sh <7char-sha> <X.Y.Z>
#
# Example:
#   manual-promote.sh abc1234 1.2.3
#
# Prerequisites:
#   - GITHUB_TOKEN with packages:write and repo scope
#   - GITHUB_USER set to your GitHub username
#   - flux CLI installed

set -euo pipefail

SHA="${1:?Usage: $0 <7char-sha> <X.Y.Z>}"
VERSION="${2:?Usage: $0 <7char-sha> <X.Y.Z>}"
REGISTRY="ghcr.io"
IMAGE="ghcr.io/${GITHUB_USER}/homelab/platform"

echo "Authenticating to GHCR..."
echo "${GITHUB_TOKEN}" | docker login "${REGISTRY}" -u "${GITHUB_USER}" --password-stdin

echo "Finding integration artifact for sha=${SHA}..."
flux list artifact "oci://${IMAGE}" | grep "integration-${SHA}" || {
  echo "ERROR: No integration-${SHA} artifact found. Check that the build workflow completed."
  exit 1
}

echo "Tagging ${IMAGE}:integration-${SHA} as validated-${SHA}..."
flux tag artifact \
  "oci://${IMAGE}:integration-${SHA}" \
  --tag "validated-${SHA}"

echo "Tagging ${IMAGE}:integration-${SHA} as ${VERSION} (stable semver)..."
flux tag artifact \
  "oci://${IMAGE}:integration-${SHA}" \
  --tag "${VERSION}"

echo "Done. Live cluster will pick up ${VERSION} on next OCIRepository poll."
echo "Verify: KUBECONFIG=~/.kube/live.yaml kubectl get ocirepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}'"

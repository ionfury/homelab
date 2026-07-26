#!/usr/bin/env bash
# Emergency rollback via artifact re-tag
# Re-tags a known-good artifact with a higher stable semver so live rolls back
# to it on the next OCIRepository poll. Prefer reverting the PR on main when
# time allows — that rebuilds a fresh artifact through the normal pipeline.
#
# Usage:
#   manual-promote.sh <known-good-7char-sha> <higher-X.Y.Z>
#
# Example:
#   manual-promote.sh abc1234 1.2.3
#
# Prerequisites:
#   - GITHUB_TOKEN with packages:write scope
#   - GITHUB_USER set to your GitHub username
#   - flux CLI installed

set -euo pipefail

SHA="${1:?Usage: $0 <known-good-7char-sha> <higher-X.Y.Z>}"
VERSION="${2:?Usage: $0 <known-good-7char-sha> <higher-X.Y.Z>}"
REGISTRY="ghcr.io"
IMAGE="ghcr.io/${GITHUB_USER}/homelab/platform"

echo "Authenticating to GHCR..."
echo "${GITHUB_TOKEN}" | docker login "${REGISTRY}" -u "${GITHUB_USER}" --password-stdin

echo "Finding artifact for sha=${SHA}..."
flux list artifact "oci://${IMAGE}" | grep "sha-${SHA}" || {
  echo "ERROR: No sha-${SHA} artifact found. Check that the build workflow completed."
  exit 1
}

echo "Tagging ${IMAGE}:sha-${SHA} as ${VERSION} (stable semver)..."
flux tag artifact \
  "oci://${IMAGE}:sha-${SHA}" \
  --tag "${VERSION}"

echo "Tagging ${IMAGE}:sha-${SHA} as validated-${SHA}..."
flux tag artifact \
  "oci://${IMAGE}:sha-${SHA}" \
  --tag "validated-${SHA}"

echo "Done. Live cluster will pick up ${VERSION} on next OCIRepository poll."
echo "Verify: kubectl --context live get ocirepository flux-system -n flux-system -o jsonpath='{.status.artifact.revision}'"

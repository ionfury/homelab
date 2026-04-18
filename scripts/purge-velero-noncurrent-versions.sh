#!/usr/bin/env bash
# Purge noncurrent S3 object versions and delete markers from Velero backup buckets.
#
# Kopia (Velero's data mover) rewrites index blobs frequently, and with S3 versioning
# enabled this creates thousands of noncurrent versions that drive up ListBucketVersions
# API costs. This script removes them in batches.
#
# Usage:
#   ./scripts/purge-velero-noncurrent-versions.sh              # all 3 buckets
#   ./scripts/purge-velero-noncurrent-versions.sh <bucket>     # specific bucket

set -euo pipefail

DEFAULT_BUCKETS=(
  "homelab-velero-backup-dev"
  "homelab-velero-backup-integration"
  "homelab-velero-backup-live"
)

BATCH_SIZE=1000

delete_noncurrent_versions() {
  local bucket="$1"
  local total_deleted=0
  local key_marker=""
  local version_marker=""
  local truncated="true"

  echo "==> Purging noncurrent versions from s3://${bucket}"

  while [[ "$truncated" == "true" ]]; do
    local cmd=(aws s3api list-object-versions --bucket "$bucket" --output json --max-items "$BATCH_SIZE")
    if [[ -n "$key_marker" ]]; then
      cmd+=(--key-marker "$key_marker" --version-id-marker "$version_marker")
    fi

    local response
    response=$("${cmd[@]}")

    local versions_payload
    versions_payload=$(echo "$response" | jq -c '[
      (.Versions // [] | map(select(.IsLatest == false)) | .[] | {Key: .Key, VersionId: .VersionId}),
      (.DeleteMarkers // [] | .[] | {Key: .Key, VersionId: .VersionId})
    ] | flatten')

    local count
    count=$(echo "$versions_payload" | jq 'length')

    if [[ "$count" -gt 0 ]]; then
      local delete_payload
      delete_payload=$(echo "$versions_payload" | jq -c '{Objects: ., Quiet: true}')

      aws s3api delete-objects \
        --bucket "$bucket" \
        --delete "$delete_payload" \
        > /dev/null

      total_deleted=$((total_deleted + count))
      echo "    Deleted ${count} objects (total: ${total_deleted})"
    fi

    truncated=$(echo "$response" | jq -r 'if .IsTruncated then "true" else "false" end')
    if [[ "$truncated" == "true" ]]; then
      key_marker=$(echo "$response" | jq -r '.NextKeyMarker // empty')
      version_marker=$(echo "$response" | jq -r '.NextVersionIdMarker // empty')
    fi
  done

  echo "==> Done: removed ${total_deleted} noncurrent versions and delete markers from s3://${bucket}"
}

if [[ $# -gt 0 ]]; then
  buckets=("$1")
else
  buckets=("${DEFAULT_BUCKETS[@]}")
fi

for bucket in "${buckets[@]}"; do
  delete_noncurrent_versions "$bucket"
done

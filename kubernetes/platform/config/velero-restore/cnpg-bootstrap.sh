#!/bin/bash
set -euo pipefail

# CNPG Bootstrap Script
#
# Pre-creates the CNPG platform Cluster CR with spec.bootstrap.recovery before
# database-config runs, so CNPG bootstraps from Barman WAL archives rather than initdb.
#
# Logic:
#   1. If the CNPG platform Cluster CR already exists -> exit 0 (cluster running normally)
#   2. If no Velero restore-platform CR exists -> exit 0 (fresh cluster, let database-config handle initdb)
#   3. Otherwise: wait for restore-platform to complete, then create the Cluster with recovery bootstrap
#
# CNPG reads spec.bootstrap ONLY on initial cluster creation. When database-config
# later applies cluster.yaml (with spec.bootstrap.initdb), CNPG ignores the bootstrap
# change because the cluster already exists. Flux SSA takes ownership cleanly.
#
# Exit codes:
#   0 -- Cluster already exists, no Velero restore, or recovery bootstrap applied
#   non-zero -- Only from set -e on unexpected errors

POLL_INTERVAL="$${POLL_INTERVAL:-15}"

echo "Phase 1: Checking if CNPG platform Cluster CR already exists..."
if kubectl get cluster.postgresql.cnpg.io platform -n database 2>/dev/null; then
  echo "CNPG platform cluster already exists, skipping recovery bootstrap."
  exit 0
fi

echo "Phase 2: Checking if a Velero restore-platform CR exists..."
if ! kubectl get restore.velero.io restore-platform -n velero 2>/dev/null; then
  echo "No Velero restore-platform found — fresh cluster. Skipping CNPG recovery bootstrap."
  exit 0
fi

echo "Phase 3: Waiting for restore-platform to reach a terminal state..."
while true; do
  phase=$(kubectl get restore.velero.io restore-platform -n velero \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

  case "$phase" in
    Completed)
      echo "Restore restore-platform completed successfully."
      break
      ;;
    Failed|PartiallyFailed|FailedValidation)
      echo "WARNING: Restore restore-platform has phase: $${phase}. Proceeding with bootstrap anyway."
      break
      ;;
    "")
      echo "Restore restore-platform has no phase yet (waiting for controller)..."
      ;;
    *)
      echo "Restore restore-platform is in phase: $${phase} (waiting for terminal state)..."
      ;;
  esac

  sleep "$POLL_INTERVAL"
done

echo "Phase 4: Creating CNPG platform Cluster CR with recovery bootstrap..."
kubectl apply -f - <<'CLUSTER_EOF'
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: platform
  namespace: database
spec:
  imageName: ghcr.io/cloudnative-pg/postgresql:${postgresql_image_version}
  instances: ${default_replica_count}
  storage:
    storageClass: fast
    size: ${database_volume_size}
  bootstrap:
    recovery:
      source: platform-backup
  externalClusters:
    - name: platform-backup
      barmanObjectStore:
        destinationPath: s3://cnpg-platform-backups/
        endpointURL: http://${garage_s3_endpoint}
        s3Credentials:
          accessKeyId:
            name: cnpg-platform-s3-credentials
            key: access-key-id
          secretAccessKey:
            name: cnpg-platform-s3-credentials
            key: secret-access-key
        wal:
          compression: gzip
        data:
          compression: gzip
CLUSTER_EOF

echo "CNPG platform Cluster CR created with recovery bootstrap. database-config will take SSA ownership on next reconciliation."

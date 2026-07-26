#!/usr/bin/env bash
# check-connection.sh - Verify CNPG cluster health and app connectivity
# Usage: check-connection.sh <cluster-name> <app-namespace> [app-name]
# cluster-name: dev, integration, or live
# app-namespace: namespace of the consuming application
# app-name: optional, used for targeted connectivity checks

set -euo pipefail

CLUSTER="${1:?Usage: check-connection.sh <cluster-name> <app-namespace> [app-name]}"
APP_NS="${2:?Usage: check-connection.sh <cluster-name> <app-namespace> [app-name]}"
APP_NAME="${3:-}"

CONTEXT="${CLUSTER}"

echo "=== CNPG Cluster Status ==="
kubectl --context "${CONTEXT}" get clusters.postgresql.cnpg.io -n database

echo ""
echo "=== Database Pods ==="
kubectl --context "${CONTEXT}" get pods -n database -l cnpg.io/cluster=platform

echo ""
echo "=== Managed Databases ==="
kubectl --context "${CONTEXT}" get databases.postgresql.cnpg.io -n database

echo ""
echo "=== Pooler Status ==="
kubectl --context "${CONTEXT}" get poolers.postgresql.cnpg.io -n database

if [[ -n "${APP_NAME}" ]]; then
  echo ""
  echo "=== Credential Secret in App Namespace (${APP_NS}) ==="
  kubectl --context "${CONTEXT}" get secret "${APP_NAME}-db-credentials" -n "${APP_NS}" \
    -o jsonpath='{.data.username}' | base64 -d && echo " (username decoded)"

  echo ""
  echo "=== Network Policy (Hubble) - App to Database ==="
  echo "Run: hubble observe --from-namespace ${APP_NS} --to-namespace database --since 5m"

  echo ""
  echo "=== Test Connection (psql debug pod) ==="
  echo "Run: kubectl --context ${CONTEXT} run -n ${APP_NS} pg-test --rm -it \\"
  echo "  --image=postgres:17 -- psql \"postgresql://<user>:<pass>@platform-pooler-rw.database.svc:5432/<dbname>\""
fi

echo ""
echo "=== CNPG Plugin (optional) ==="
echo "kubectl cnpg status platform -n database"

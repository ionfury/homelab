#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  SEEDING CNPG DATABASE SENTINEL"
echo "============================================================"
echo ""

SENTINEL_UUID=$(tail -1 "${CHECKSUM_FILE}")
echo "Sentinel UUID: ${SENTINEL_UUID}"

PRIMARY_POD=$(kubectl --context "${CONTEXT}" -n database get pods \
  -l cnpg.io/cluster=platform,role=primary \
  -o jsonpath='{.items[0].metadata.name}')
echo "Primary pod: ${PRIMARY_POD}"

PGPASSWORD=$(kubectl --context "${CONTEXT}" -n database get secret cnpg-platform-superuser \
  -o jsonpath='{.data.password}' | base64 -d)

echo "Creating sentinel table and inserting row..."
kubectl --context "${CONTEXT}" -n database exec "${PRIMARY_POD}" -- \
  env PGPASSWORD="${PGPASSWORD}" psql -U postgres -d postgres -c "
    CREATE TABLE IF NOT EXISTS ${DB_SENTINEL_TABLE} (
      id SERIAL PRIMARY KEY,
      exercise_id TEXT NOT NULL,
      sentinel_uuid TEXT NOT NULL,
      created_at TIMESTAMPTZ DEFAULT NOW()
    );
    INSERT INTO ${DB_SENTINEL_TABLE} (exercise_id, sentinel_uuid)
    VALUES ('${EXERCISE_ID}', '${SENTINEL_UUID}');"

echo "CNPG sentinel seeded."
echo ""

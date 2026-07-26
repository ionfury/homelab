#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  VERIFYING CNPG DATABASE SENTINEL"
echo "============================================================"
echo ""

EXPECTED_UUID=$(tail -1 "${CHECKSUM_FILE}")
echo "Expected UUID: ${EXPECTED_UUID}"

PRIMARY_POD=$(kubectl --context "${CONTEXT}" -n database get pods \
  -l cnpg.io/cluster=platform,role=primary \
  -o jsonpath='{.items[0].metadata.name}')
echo "Primary pod: ${PRIMARY_POD}"

PGPASSWORD=$(kubectl --context "${CONTEXT}" -n database get secret cnpg-platform-superuser \
  -o jsonpath='{.data.password}' | base64 -d)
echo ${PGPASSWORD}
RESULT=$(kubectl --context "${CONTEXT}" -n database exec "${PRIMARY_POD}" -- \
  env PGPASSWORD="${PGPASSWORD}" psql -U postgres -d postgres -t -A -c "
    SELECT sentinel_uuid
    FROM ${DB_SENTINEL_TABLE}
    WHERE exercise_id = '${EXERCISE_ID}'
    ORDER BY created_at DESC
    LIMIT 1;" 2>/dev/null | tr -d ' ')

echo "Retrieved UUID: ${RESULT}"

if [ -z "${RESULT}" ] || [ "${RESULT}" != "${EXPECTED_UUID}" ]; then
  echo ""
  echo "FAIL: CNPG sentinel row missing or mismatched -- Barman recovery did not restore data."
  echo "  Expected: ${EXPECTED_UUID}"
  echo "  Got:      ${RESULT:-<empty>}"
  exit 1
fi

echo ""
echo "PASS: CNPG database sentinel verified."
echo ""

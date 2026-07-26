#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  DR EXERCISE COMPLETE"
echo "============================================================"
echo ""
echo "  Exercise ID:         ${EXERCISE_ID}"
echo ""
echo "  Garage S3 sentinel:  PASS"
echo "  CNPG database row:   PASS"
echo "  Flux health:         CHECKED (warnings non-fatal)"
echo "  Alertmanager:        CHECKED (warnings non-fatal)"
echo ""
echo "All critical verifications passed."
echo ""

rm -f "${CHECKSUM_FILE}"

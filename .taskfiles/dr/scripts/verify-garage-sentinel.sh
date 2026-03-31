#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  VERIFYING GARAGE S3 SENTINEL"
echo "============================================================"
echo ""

EXPECTED_CHECKSUM=$(head -1 "${CHECKSUM_FILE}")
EXPECTED_UUID=$(tail -1 "${CHECKSUM_FILE}")
echo "Expected UUID:     ${EXPECTED_UUID}"
echo "Expected checksum: ${EXPECTED_CHECKSUM}"

ACCESS_KEY=$(kubectl --context "${CONTEXT}" -n garage get secret dr-test-s3-credentials \
  -o jsonpath='{.data.access-key-id}' | base64 -d)
SECRET_KEY=$(kubectl --context "${CONTEXT}" -n garage get secret dr-test-s3-credentials \
  -o jsonpath='{.data.secret-access-key}' | base64 -d)

echo "Reading sentinel from s3://dr-test/sentinel.txt..."
RETRIEVED=$(kubectl --context "${CONTEXT}" run dr-sentinel-read \
  --namespace garage \
  --image=amazon/aws-cli:latest \
  --restart=Never \
  --rm \
  --attach \
  --quiet \
  --overrides="{
    \"spec\": {
      \"containers\": [{
        \"name\": \"dr-sentinel-read\",
        \"image\": \"amazon/aws-cli:latest\",
        \"command\": [\"sh\", \"-c\",
          \"aws s3 cp s3://dr-test/sentinel.txt - --endpoint-url http://garage.garage.svc.cluster.local:3900 --region garage\"],
        \"env\": [
          {\"name\": \"AWS_ACCESS_KEY_ID\", \"value\": \"${ACCESS_KEY}\"},
          {\"name\": \"AWS_SECRET_ACCESS_KEY\", \"value\": \"${SECRET_KEY}\"}
        ],
        \"securityContext\": {
          \"allowPrivilegeEscalation\": false,
          \"capabilities\": {\"drop\": [\"ALL\"]},
          \"runAsNonRoot\": true,
          \"runAsUser\": 65534
        }
      }],
      \"restartPolicy\": \"Never\"
    }
  }" -- true 2>/dev/null | tr -d '\n')

ACTUAL_CHECKSUM=$(echo -n "${RETRIEVED}" | shasum -a 256 | cut -d' ' -f1)
echo "Retrieved UUID:    ${RETRIEVED}"
echo "Actual checksum:   ${ACTUAL_CHECKSUM}"

if [ "${EXPECTED_CHECKSUM}" != "${ACTUAL_CHECKSUM}" ]; then
  echo ""
  echo "FAIL: Garage sentinel checksum mismatch -- PVC restore or Garage S3 data integrity failure."
  exit 1
fi

echo ""
echo "PASS: Garage S3 sentinel verified."
echo ""

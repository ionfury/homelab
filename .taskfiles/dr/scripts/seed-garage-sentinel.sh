#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  SEEDING GARAGE S3 SENTINEL"
echo "============================================================"
echo ""
echo "Sentinel UUID: ${SENTINEL_UUID}"

ACCESS_KEY=$(kubectl --context "${CONTEXT}" -n garage get secret dr-test-s3-credentials \
  -o jsonpath='{.data.access-key-id}' | base64 -d)
SECRET_KEY=$(kubectl --context "${CONTEXT}" -n garage get secret dr-test-s3-credentials \
  -o jsonpath='{.data.secret-access-key}' | base64 -d)

echo "Writing sentinel to s3://dr-test/sentinel.txt..."
kubectl --context "${CONTEXT}" run dr-sentinel-write \
  --namespace garage \
  --image=amazon/aws-cli:latest \
  --restart=Never \
  --rm \
  --attach \
  --overrides="{
    \"spec\": {
      \"containers\": [{
        \"name\": \"dr-sentinel-write\",
        \"image\": \"amazon/aws-cli:latest\",
        \"command\": [\"sh\", \"-c\",
          \"echo '${SENTINEL_UUID}' | aws s3 cp - s3://dr-test/sentinel.txt --endpoint-url http://garage.garage.svc.cluster.local:3900 --region garage\"],
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
  }" -- true

# Store checksum (line 1) and raw UUID (line 2) for verification
echo -n "${SENTINEL_UUID}" | shasum -a 256 | cut -d' ' -f1 > "${CHECKSUM_FILE}"
echo "${SENTINEL_UUID}" >> "${CHECKSUM_FILE}"

echo "Sentinel written. Checksum: $(head -1 "${CHECKSUM_FILE}")"
echo ""

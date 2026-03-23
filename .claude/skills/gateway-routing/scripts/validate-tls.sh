#!/usr/bin/env bash
# Usage: CLUSTER=live ./validate-tls.sh [gateway-name]
# Validates TLS certificate status for the given gateway (default: external).
# Requires CLUSTER env var (dev, integration, or live).
#
# Example:
#   CLUSTER=live ./validate-tls.sh external
#   CLUSTER=live ./validate-tls.sh internal

set -euo pipefail

GATEWAY="${1:-external}"
CONTEXT="${CLUSTER:-live}"

echo "=== Certificate status (istio-gateway namespace) ==="
kubectl --context "$CONTEXT" get certificates -n istio-gateway

echo ""
echo "=== Certificate detail: $GATEWAY ==="
kubectl --context "$CONTEXT" describe certificate "$GATEWAY" -n istio-gateway

echo ""
echo "=== ClusterIssuer health ==="
kubectl --context "$CONTEXT" get clusterissuers

echo ""
echo "=== CertificateRequests (recent issuance attempts) ==="
kubectl --context "$CONTEXT" get certificaterequests -n istio-gateway

echo ""
echo "=== TLS secret certificate details ==="
kubectl --context "$CONTEXT" get secret "${GATEWAY}-tls" -n istio-gateway \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text | \
  grep -E '(Subject:|Issuer:|Not Before|Not After|DNS:)'

echo ""
echo "=== WAF endpoint test (external gateway only) ==="
if [ "$GATEWAY" = "external" ]; then
  GATEWAY_IP=$(kubectl --context "$CONTEXT" get gateway external -n istio-gateway \
    -o jsonpath='{.metadata.annotations.lbipam\.cilium\.io/ips}' 2>/dev/null || echo "")
  if [ -n "$GATEWAY_IP" ]; then
    EXTERNAL_DOMAIN=$(kubectl --context "$CONTEXT" get cm -n flux-system cluster-vars \
      -o jsonpath='{.data.external_domain}' 2>/dev/null || echo "UNKNOWN")
    echo "Gateway IP: $GATEWAY_IP"
    echo "Testing SNI routing (expect HTTP 200/301/302, not connection reset):"
    curl -ksI --resolve "test.$EXTERNAL_DOMAIN:443:$GATEWAY_IP" \
      "https://test.$EXTERNAL_DOMAIN/" --max-time 5 | head -1 || echo "Connection failed (expected if no route for test.*)"
  else
    echo "Could not determine gateway IP"
  fi
fi

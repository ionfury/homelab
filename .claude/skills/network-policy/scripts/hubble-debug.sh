#!/usr/bin/env bash
# Usage: ./hubble-debug.sh <namespace> [since]
# Runs a structured Hubble observation sequence for debugging dropped traffic.
# Requires hubble CLI and an active port-forward to hubble-relay:
#   kubectl port-forward -n kube-system svc/hubble-relay 4245:80 &
#
# Example:
#   ./hubble-debug.sh my-app 5m
#   ./hubble-debug.sh authelia 10m

set -euo pipefail

NS="${1:?Usage: $0 <namespace> [since]}"
SINCE="${2:-5m}"

echo "=== All DROPPED flows in namespace: $NS (last $SINCE) ==="
hubble observe --verdict DROPPED --namespace "$NS" --since "$SINCE"

echo ""
echo "=== DROPPED with src/dst/port detail ==="
hubble observe --verdict DROPPED --namespace "$NS" --since "$SINCE" -o json 2>/dev/null | \
  jq -r 'select(.source != null) | [
    (.source.namespace // "?") + "/" + (.source.pod_name // "?"),
    "->",
    (.destination.namespace // "?") + "/" + (.destination.pod_name // "?"),
    "port:", (.l4.TCP.destination_port // .l4.UDP.destination_port // "?" | tostring)
  ] | join(" ")' | sort | uniq -c | sort -rn || echo "(no JSON output)"

echo ""
echo "=== DNS egress (UDP 53) ==="
hubble observe --namespace "$NS" --protocol UDP --port 53 --since "$SINCE" | tail -5

echo ""
echo "=== Database egress (TCP 5432) ==="
hubble observe --namespace "$NS" --to-namespace database --port 5432 --since "$SINCE" | tail -5

echo ""
echo "=== Internet egress (TCP 443) ==="
hubble observe --namespace "$NS" --to-identity world --port 443 --since "$SINCE" | tail -5

echo ""
echo "=== Gateway ingress from istio-gateway ==="
hubble observe --from-namespace istio-gateway --to-namespace "$NS" --since "$SINCE" | tail -5

echo ""
echo "=== Prometheus scrape ingress from monitoring ==="
hubble observe --from-namespace monitoring --to-namespace "$NS" --since "$SINCE" | tail -5

echo ""
echo "=== Active CNPs and CCNPs for namespace: $NS ==="
kubectl get cnp -n "$NS" 2>/dev/null || echo "(no CNPs)"
kubectl get ccnp 2>/dev/null | grep -E 'NAME|baseline|profile' || echo "(no matching CCNPs)"

echo ""
echo "=== Namespace labels ==="
kubectl get namespace "$NS" --show-labels

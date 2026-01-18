# Network Policy Verification with Hubble

This runbook covers verifying network policy behavior using Hubble CLI and UI.

## Prerequisites

- `hubble` CLI installed (via Brewfile)
- kubectl context set to the target cluster
- Hubble relay accessible (port-forward if needed)

## Setup Hubble Access

```bash
# Port-forward Hubble relay (if not using Cilium LoadBalancer service)
kubectl port-forward -n kube-system svc/hubble-relay 4245:80 &

# Verify Hubble connectivity
hubble status
```

## Common Verification Tasks

### Check for Dropped Traffic

```bash
# Real-time dropped traffic in the last 5 minutes
hubble observe --verdict DROPPED --since 5m

# Filter by namespace
hubble observe --verdict DROPPED --namespace home-assistant --since 5m

# Show source and destination details
hubble observe --verdict DROPPED --since 5m -o json | jq '.source, .destination'
```

### Verify DNS Resolution Works

```bash
# Check DNS flows from a specific namespace
hubble observe --namespace home-assistant --protocol UDP --port 53 --since 5m

# Verify DNS requests reach kube-dns
hubble observe --to-namespace kube-system --to-label k8s-app=kube-dns --since 5m
```

### Verify Prometheus Scraping

```bash
# Check scrape traffic from Prometheus
hubble observe --from-namespace monitoring --from-label app.kubernetes.io/name=prometheus --since 5m

# Verify scrape to a specific namespace
hubble observe --from-namespace monitoring --to-namespace home-assistant --since 5m
```

### Verify Gateway Ingress

```bash
# Check traffic from external gateway
hubble observe --from-namespace istio-gateway --from-label gateway.networking.k8s.io/gateway-name=external --since 5m

# Check traffic from internal gateway
hubble observe --from-namespace istio-gateway --from-label gateway.networking.k8s.io/gateway-name=internal --since 5m
```

### Verify Internet Egress

```bash
# Check world egress from a namespace
hubble observe --namespace home-assistant --to-identity world --since 5m

# Filter by port (HTTPS)
hubble observe --namespace home-assistant --to-identity world --port 443 --since 5m
```

### Verify Shared Resource Access

```bash
# Check PostgreSQL access
hubble observe --to-namespace database --port 5432 --since 5m

# Check Garage S3 access
hubble observe --to-namespace garage --port 3900 --since 5m
```

## Profile Verification Test

For each profile, deploy a test pod and verify expected connectivity:

```bash
# Create test namespace with profile
kubectl create namespace test-standard
kubectl label namespace test-standard network-policy.homelab/profile=standard

# Deploy test pod
kubectl run test-pod --namespace test-standard --image=curlimages/curl --command -- sleep infinity

# Test DNS
kubectl exec -n test-standard test-pod -- nslookup kubernetes.default

# Test internet egress (should work for standard profile)
kubectl exec -n test-standard test-pod -- curl -s -o /dev/null -w "%{http_code}" https://httpbin.org/get

# Cleanup
kubectl delete namespace test-standard
```

## Escape Hatch Verification

```bash
# Enable escape hatch
kubectl label namespace <namespace> network-policy.homelab/enforcement=disabled

# Verify traffic flows (should show FORWARDED instead of DROPPED)
hubble observe --namespace <namespace> --since 1m

# Re-enable enforcement
kubectl label namespace <namespace> network-policy.homelab/enforcement-

# Verify alert fired
kubectl get prometheusrule -n monitoring network-policy-alerts
```

## Flow Export for Analysis

```bash
# Export flows for LLM analysis
hubble observe --namespace <namespace> --since 24h --output csv > flows.csv

# Export as JSON for programmatic analysis
hubble observe --namespace <namespace> --since 24h --output jsonpb > flows.json

# Summary of unique destinations
hubble observe --namespace <namespace> --since 1h --output json | \
  jq -r '.destination.namespace + "/" + .destination.pod_name + ":" + (.l4.TCP.destination_port // .l4.UDP.destination_port | tostring)' | \
  sort -u
```

## Troubleshooting

### Policy Not Taking Effect

1. Verify policy is applied: `kubectl get ccnp,cnp -A`
2. Check Cilium agent logs: `kubectl logs -n kube-system -l k8s-app=cilium`
3. Verify endpoint identity: `kubectl exec -n kube-system cilium-xxxxx -- cilium endpoint list`

### Unexpected Drops

1. Identify the policy causing drops:
   ```bash
   hubble observe --verdict DROPPED -o json | jq '.drop_reason_desc'
   ```
2. Check if baseline policies are applied
3. Verify namespace labels match profile selector

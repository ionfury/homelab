# Network Policy Architecture - Claude Reference

Cilium-based network segmentation using CiliumNetworkPolicy (CNP) and CiliumClusterwideNetworkPolicy (CCNP) resources.

---

## Core Architecture

### Implicit Default-Deny

**No explicit `default-deny` policy is needed.** Baselines with `endpointSelector: {}` enable Cilium enforcement mode for ALL pods, providing implicit deny. Once any policy selects a pod, all traffic not explicitly allowed is denied.

This works because:
1. Cilium enters "enforcement mode" for endpoints when ANY policy selects them
2. Baseline CCNPs use `endpointSelector: {}` which selects ALL pods cluster-wide
3. All traffic is implicitly denied unless an explicit allow rule matches

### Two-Layer System

**Baselines** (apply to all pods via empty selector):
- DNS egress to kube-dns
- Health probe ingress from kubelet
- Prometheus scrape ingress from monitoring namespace
- Kube-API egress (opt-in via namespace label)

**Profiles** (apply via namespace label `network-policy.homelab/profile=<profile>`):
- `isolated` - No external ingress, no internet egress
- `internal` - Internal gateway ingress only
- `internal-egress` - Internal gateway ingress + HTTPS egress
- `standard` - Both gateways ingress + HTTPS egress

### Platform-Tier Exclusions

Platform namespaces (`kube-system`, `monitoring`, `database`, etc.) have their own hand-crafted CNPs in the `platform/` directory. These namespaces do NOT use profiles - they require precise, per-namespace rules for their specific traffic patterns.

---

## Directory Structure

```
network-policy/
├── baselines/           # Universal allow rules (CCNPs)
│   ├── dns-egress.yaml            # All pods -> kube-dns
│   ├── health-probes.yaml         # kubelet -> all pods
│   ├── prometheus-scrape.yaml     # Prometheus -> all pods
│   └── kube-api-access.yaml       # Opt-in kube-apiserver egress
├── profiles/            # Namespace profile CCNPs
│   ├── profile-isolated.yaml      # Minimal: DNS + metrics only
│   ├── profile-internal.yaml      # Internal gateway ingress
│   ├── profile-internal-egress.yaml  # Internal gateway + HTTPS egress
│   └── profile-standard.yaml      # Both gateways + HTTPS egress
├── platform/            # Hand-crafted CNPs for platform namespaces
│   ├── kube-system.yaml
│   ├── monitoring.yaml
│   ├── database.yaml
│   ├── istio-system.yaml
│   ├── istio-gateway.yaml
│   └── ... (other platform namespaces)
├── shared-resources/    # Opt-in access to shared services
│   ├── access-postgres.yaml       # Database access
│   └── access-garage-s3.yaml      # Object storage access
└── kustomization.yaml
```

---

## Profile Reference

| Profile | Ingress | Egress | Use Case |
|---------|---------|--------|----------|
| `isolated` | None (metrics only) | DNS only | Batch jobs, workers with no network needs |
| `internal` | Internal gateway | DNS only | Internal tools (dashboards, admin UIs) |
| `internal-egress` | Internal gateway | DNS + HTTPS | Internal apps calling external APIs |
| `standard` | Both gateways | DNS + HTTPS | Public-facing web applications |

### Profile Selection

Namespaces select a profile via label:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    network-policy.homelab/profile: standard  # Select profile
```

---

## Access Labels

Namespaces can opt-in to additional capabilities via labels:

| Label | Capability |
|-------|------------|
| `access.network-policy.homelab/kube-api=true` | Egress to Kubernetes API (port 6443) |
| `access.network-policy.homelab/postgres=true` | Egress to PostgreSQL in database namespace (port 5432) |
| `access.network-policy.homelab/garage-s3=true` | Egress to Garage S3 in garage namespace (port 3900) |

### Adding Access

```bash
# Grant PostgreSQL access to a namespace
kubectl label namespace my-app access.network-policy.homelab/postgres=true

# Grant Kubernetes API access
kubectl label namespace my-app access.network-policy.homelab/kube-api=true
```

---

## Escape Hatch

For emergencies when network policies block legitimate traffic:

```bash
# Disable enforcement for a namespace
kubectl label namespace <namespace> network-policy.homelab/enforcement=disabled

# Re-enable after debugging
kubectl label namespace <namespace> network-policy.homelab/enforcement-
```

**Alert behavior:**
- `NetworkPolicyEnforcementDisabled` (warning) fires after 5 minutes
- `NetworkPolicyEnforcementDisabledLong` (critical) fires after 24 hours

See `docs/runbooks/network-policy-escape-hatch.md` for full procedure.

---

## HBONE Traffic (Istio Ambient)

Istio Ambient mode uses HBONE (HTTP-based overlay) for mesh traffic. Platform CNPs must allow port 15008 for ztunnel-to-ztunnel communication.

Required rules in platform namespace CNPs:

```yaml
ingress:
  # HBONE from ztunnel
  - fromEndpoints:
      - matchLabels:
          io.kubernetes.pod.namespace: istio-system
          app: ztunnel
    toPorts:
      - ports:
          - port: "15008"
            protocol: TCP

egress:
  # HBONE to ztunnel
  - toEndpoints:
      - matchLabels:
          io.kubernetes.pod.namespace: istio-system
          app: ztunnel
    toPorts:
      - ports:
          - port: "15008"
            protocol: TCP
```

---

## Debugging with Hubble

### Check for Dropped Traffic

```bash
# Real-time drops
hubble observe --verdict DROPPED --since 5m

# Drops in a specific namespace
hubble observe --verdict DROPPED --namespace my-app --since 5m

# Show source and destination details
hubble observe --verdict DROPPED --since 5m -o json | jq '.source, .destination'
```

### Verify Specific Flows

```bash
# DNS traffic from a namespace
hubble observe --namespace my-app --protocol UDP --port 53 --since 5m

# Prometheus scraping
hubble observe --from-namespace monitoring --to-namespace my-app --since 5m

# Internet egress
hubble observe --namespace my-app --to-identity world --port 443 --since 5m

# Gateway ingress
hubble observe --from-namespace istio-gateway --to-namespace my-app --since 5m
```

### Identify Policy Causing Drops

```bash
# Get drop reasons
hubble observe --verdict DROPPED -o json | jq '.drop_reason_desc'

# Export flows for analysis
hubble observe --namespace my-app --since 1h --output json > /tmp/flows.json

# Summarize unique destinations
cat /tmp/flows.json | \
  jq -r '.destination.namespace + "/" + (.destination.labels // {})["k8s:app.kubernetes.io/name"] + ":" + (.l4.TCP.destination_port // .l4.UDP.destination_port | tostring)' | \
  sort -u
```

### Check Policy Status

```bash
# List all network policies
kubectl get ccnp,cnp -A

# Check Cilium endpoint policy enforcement
kubectl exec -n kube-system cilium-xxxxx -- cilium endpoint list

# Check Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium
```

See `docs/runbooks/network-policy-verification.md` for comprehensive verification procedures.

---

## Common Tasks

### Adding a New Application Namespace

1. Create namespace with profile label:
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: my-app
     labels:
       network-policy.homelab/profile: standard
   ```

2. Add access labels if needed:
   ```bash
   kubectl label namespace my-app access.network-policy.homelab/postgres=true
   ```

3. Verify connectivity:
   ```bash
   hubble observe --namespace my-app --verdict DROPPED --since 5m
   ```

### Adding a New Platform Namespace CNP

1. Create CNP in `platform/<namespace>.yaml`
2. Include baseline capabilities explicitly:
   - DNS egress to kube-system/kube-dns
   - Prometheus scrape ingress from monitoring
   - Health probe ingress from `health` entity and `169.254.0.0/16`
3. Add HBONE rules if namespace participates in the mesh
4. Add to `platform/kustomization.yaml`

### Granting Database Access

```bash
# Add PostgreSQL access
kubectl label namespace my-app access.network-policy.homelab/postgres=true

# Verify egress is allowed
hubble observe --namespace my-app --to-namespace database --port 5432 --since 5m
```

### Emergency Traffic Bypass

```bash
# 1. Disable enforcement
kubectl label namespace my-app network-policy.homelab/enforcement=disabled

# 2. Verify traffic flows
hubble observe --namespace my-app --since 1m

# 3. Investigate and fix root cause (see escape hatch runbook)

# 4. Re-enable enforcement
kubectl label namespace my-app network-policy.homelab/enforcement-
```

---

## Anti-Patterns

- **NEVER** create explicit `default-deny` policies - baselines provide implicit deny
- **NEVER** use profiles for platform namespaces - they need custom CNPs
- **NEVER** hardcode IP addresses - use endpoint selectors and entities
- **NEVER** allow `any` port - always specify explicit port lists
- **NEVER** disable enforcement without following the escape hatch runbook

---

## Related Documentation

- `docs/runbooks/network-policy-escape-hatch.md` - Emergency bypass procedure
- `docs/runbooks/network-policy-verification.md` - Hubble verification commands
- `kubernetes/platform/config/cilium/` - Cilium configuration

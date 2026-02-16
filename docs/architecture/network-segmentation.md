# Network Segmentation

Enterprise-grade network segmentation using Cilium CiliumClusterwideNetworkPolicy (CCNP) and CiliumNetworkPolicy (CNP) resources, enforcing implicit default-deny across all clusters.

## Design Philosophy

All cluster network traffic is **implicitly denied** unless explicitly allowed. This mirrors enterprise zero-trust principles where workloads must justify every network connection. The architecture uses a two-tier model that separates platform concerns from application concerns.

## Two-Tier Policy Model

### Tier 1: Baselines (Cluster-Wide)

Baseline CCNPs use an **empty `endpointSelector`** to match all pods cluster-wide. This triggers Cilium's enforcement mode — once any policy selects an endpoint, all traffic not explicitly allowed is denied. No explicit "default deny" policy is needed.

| Baseline | Purpose | Key Detail |
|----------|---------|------------|
| `dns-egress` | All pods can reach CoreDNS | UDP/TCP 53 to kube-system/kube-dns |
| `prometheus-scrape` | Prometheus can scrape all pods | No port restriction (any metrics port) |
| `health-probes` | Kubelet health checks and Cilium health | Uses reserved entities: health, host, remote-node, kube-apiserver |
| `intra-namespace` | Free communication within a namespace | Pods talk freely to same-namespace peers |
| `kube-api-access` | Opt-in Kubernetes API access | Requires `access.network-policy.homelab/kube-api=true` label |
| `escape-hatch-allow-all` | Emergency bypass | Triggered by `network-policy.homelab/enforcement=disabled` |
| `hbone-mesh` | Istio Ambient HBONE traffic | Port 15008 for namespaces with `istio.io/dataplane-mode=ambient` |
| `bgp-peering` | BGP between nodes and external router | TCP 179, uses `${bgp_router_ip}` substitution |

### Tier 2: Profiles (Application Namespaces)

Application namespaces select a profile via namespace label. Each profile is a CCNP that matches on `network-policy.homelab/profile=<name>`:

| Profile | Ingress | Egress | Use Case |
|---------|---------|--------|----------|
| `isolated` | Prometheus scraping only | DNS only | Batch jobs, workers |
| `internal` | Internal gateway only | DNS only (baselines) | Internal dashboards |
| `internal-egress` | Internal gateway only | DNS + HTTPS (443 only) | Internal apps calling external APIs |
| `standard` | Both external and internal gateways | DNS + HTTPS (443 only) | Public-facing web apps |

Egress profiles deliberately restrict outbound to HTTPS (port 443) only — HTTP is blocked for security.

## Shared Resource Access

Cross-namespace access to shared platform services uses a label-based opt-in model. Each shared resource has a paired CCNP:

| Label | Resource | Port | CCNP |
|-------|----------|------|------|
| `access.network-policy.homelab/postgres=true` | PostgreSQL | TCP 5432 | `access-postgres-egress` |
| `access.network-policy.homelab/dragonfly=true` | Dragonfly (Redis) | TCP 6379 | `access-dragonfly-egress` |
| `access.network-policy.homelab/garage-s3=true` | Garage S3 | TCP 3900 | `access-garage-s3-egress` |
| `access.network-policy.homelab/kube-api=true` | Kubernetes API | TCP 6443/443 | `kube-api-access` (baseline) |

Each access CCNP creates an **egress** rule from the labeled namespace. The corresponding **ingress** rule lives in the platform namespace's hand-crafted CNP (e.g., `database.yaml` allows ingress on 5432 from namespaces with the postgres label).

## Platform Namespace Policies

Platform namespaces (`monitoring`, `database`, `cache`, `garage`, `longhorn-system`, `istio-gateway`, `system-upgrade`, `kromgo`) use hand-crafted CNPs instead of profiles. These are more specific and audit-reviewed:

| Namespace | Ingress Sources | Egress Destinations |
|-----------|-----------------|---------------------|
| `monitoring` | istio-gateway (Grafana/Prometheus UI), all pods (Loki log shipping), kube-apiserver | kube-apiserver, all pods (scraping), world (webhooks, HTTPS 443) |
| `database` | labeled namespaces (5432), database (replication), monitoring (metrics) | kube-apiserver, garage (S3 backups), world (S3), database (replication) |
| `cache` | labeled namespaces (6379), cache (replication), monitoring (metrics) | cache (replication), garage (S3 snapshots) |
| `garage` | labeled namespaces (3900), longhorn/database/cache (backups), garage (replication) | garage (replication and admin) |
| `istio-gateway` | world (HTTP/HTTPS), monitoring, istio-system | cluster (all backends), istio-system (xDS), world (JWKS/OIDC) |
| `longhorn-system` | cluster (CSI), monitoring, istio-gateway (UI), kube-apiserver | kube-apiserver, cluster (replication), garage (S3), world (S3) |
| `system-upgrade` | monitoring (metrics) | kube-apiserver, host (Talos API 50000) |
| `kromgo` | istio-gateway, monitoring | monitoring (Prometheus 9090) |

## Monitoring and Alerting

### Escape Hatch Alerts

| Alert | Severity | Fires After | Meaning |
|-------|----------|-------------|---------|
| `NetworkPolicyEnforcementDisabled` | warning | 5 minutes | Escape hatch is active, should be temporary |
| `NetworkPolicyEnforcementDisabledLong` | critical | 24 hours | Attack surface significantly increased |

### Cilium Health Alerts

Comprehensive Cilium monitoring covers agent availability, endpoint health, BPF resources, policy enforcement, and network health. Key alerts include `CiliumPolicyDropsHigh`, `CiliumAgentDown`, `CiliumBPFMapPressureCritical`, and `CiliumConntrackTableFull`.

## Debugging with Hubble

Hubble provides flow-level visibility into all network traffic:

```bash
# Check for dropped traffic in a namespace
hubble observe --verdict DROPPED --namespace <ns> --since 5m

# Verify DNS resolution
hubble observe --namespace <ns> --protocol UDP --port 53 --since 5m

# Verify Prometheus scraping
hubble observe --from-namespace monitoring --to-namespace <ns> --since 5m

# Verify gateway ingress
hubble observe --from-namespace istio-gateway --since 5m

# Export flows for analysis
hubble observe --namespace <ns> --since 1h --output json > flows.json
```

## File Organization

```
kubernetes/platform/config/network-policy/
├── baselines/           # Universal allows (DNS, health, Prometheus, intra-namespace)
├── profiles/            # Application namespace profiles (isolated → standard)
├── platform/            # Hand-crafted CNPs for platform namespaces
└── shared-resources/    # Opt-in access (postgres, dragonfly, garage-s3)
```

## Key Design Decisions

1. **Implicit default-deny over explicit**: Baselines with empty `endpointSelector` activate Cilium enforcement. No standalone "deny all" policy needed.
2. **Entity-based selection over IP-based**: Uses Cilium entities (`world`, `cluster`, `host`, `kube-apiserver`) rather than hardcoded IPs, surviving node IP changes.
3. **Namespace labels over pod labels**: Profile selection and shared resource access use namespace-level labels, enabling operators to grant access without modifying workload manifests.
4. **HTTPS-only egress**: Profiles block HTTP (port 80) to the internet — only HTTPS (443) is allowed.
5. **Port-explicit rules**: All policies specify explicit port lists. No "allow any port" rules exist.
6. **policyDenyResponse: icmp**: Cilium returns ICMP unreachable for denied connections, enabling fast failure detection rather than silent timeouts.

## Related Resources

- Operational reference: `kubernetes/platform/config/network-policy/CLAUDE.md`
- Design document: `docs/plans/network-policy-architecture.md`
- Escape hatch runbook: `docs/runbooks/network-policy-escape-hatch.md`
- Verification runbook: `docs/runbooks/network-policy-verification.md`

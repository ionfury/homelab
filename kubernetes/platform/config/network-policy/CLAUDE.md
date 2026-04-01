# Network Policy Architecture - Claude Reference

Cilium-based network segmentation using CiliumNetworkPolicy (CNP) and CiliumClusterwideNetworkPolicy (CCNP) resources.

## Core Architecture

All traffic is implicitly denied by Cilium's default-deny model. Baselines enable enforcement; profiles grant namespace-level ingress/egress permissions.

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

Platform namespaces (`kube-system`, `monitoring`, `database`, etc.) have their own hand-crafted CNPs in the `platform/` directory. These namespaces do NOT use profiles.

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
│   ├── cache.yaml                 # Dragonfly (Redis) cache instances
│   ├── database.yaml              # CloudNative-PG data plane (clusters + poolers)
│   ├── garage.yaml                # Garage S3 storage
│   ├── istio-gateway.yaml         # Istio ingress gateways
│   ├── kromgo.yaml                # Kromgo status badges
│   ├── longhorn-system.yaml       # Longhorn storage
│   ├── monitoring.yaml            # Prometheus, Grafana, Alertmanager, Loki
│   └── system-upgrade.yaml        # Tuppr upgrade controller
├── shared-resources/    # Opt-in access to shared services
│   ├── access-dragonfly.yaml      # Dragonfly (Redis) access
│   ├── access-postgres.yaml       # Database access
│   └── access-garage-s3.yaml      # Object storage access
└── kustomization.yaml
```

## Profile Reference

| Profile | Ingress | Egress | Use Case |
|---------|---------|--------|----------|
| `isolated` | None (metrics only) | DNS only | Batch jobs, workers with no network needs |
| `internal` | Internal gateway | DNS only | Internal tools (dashboards, admin UIs) |
| `internal-egress` | Internal gateway | DNS + HTTPS | Internal apps calling external APIs |
| `standard` | Both gateways | DNS + HTTPS | Public-facing web applications |

Namespaces select a profile via the label `network-policy.homelab/profile: <profile>` in `kubernetes/platform/namespaces.yaml`.

## Access Labels

Namespaces can opt-in to additional capabilities via labels:

| Label | Capability |
|-------|------------|
| `access.network-policy.homelab/kube-api=true` | Egress to Kubernetes API (port 6443) |
| `access.network-policy.homelab/dragonfly=true` | Egress to Dragonfly in cache namespace (port 6379) |
| `access.network-policy.homelab/postgres=true` | Egress to PostgreSQL in database namespace (port 5432) |
| `access.network-policy.homelab/garage-s3=true` | Egress to Garage S3 in garage namespace (port 3900) |

## Escape Hatch

For emergencies when network policies block legitimate traffic, disable enforcement with `kubectl label namespace <namespace> network-policy.homelab/enforcement=disabled` and re-enable with `kubectl label namespace <namespace> network-policy.homelab/enforcement-`.

**Alert behavior:**
- `NetworkPolicyEnforcementDisabled` (warning) fires after 5 minutes
- `NetworkPolicyEnforcementDisabledLong` (critical) fires after 24 hours

See `docs/runbooks/network-policy-escape-hatch.md` for full procedure.

## HBONE Traffic (Istio Ambient)

Istio Ambient mode uses HBONE (HTTP-based overlay) for mesh traffic. Platform CNPs must allow port 15008 for ztunnel-to-ztunnel communication. Without this rule, pod-to-pod traffic within the mesh is silently dropped.

For required HBONE YAML, see the network-policy skill.

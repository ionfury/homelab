# Network Policy Architecture Plan

## Overview

This document defines the architectural approach for implementing network segmentation across the homelab Kubernetes clusters using Cilium Network Policies. The design balances security (protecting against untrusted off-the-shelf workloads) with operational overhead (minimizing per-app policy authoring).

### Goals

- **Default-deny posture**: All traffic blocked unless explicitly permitted
- **Low onboarding friction**: Adding a new app should require only namespace annotations/labels, not custom policies
- **Auditable access**: Easy to answer "what can talk to what?" via label queries
- **Escape hatch**: Per-namespace kill-switch for incident recovery
- **Platform protection**: Critical infrastructure gets hand-crafted, tight policies

### Technology Choice

**Cilium CiliumClusterwideNetworkPolicy (CCNP)** at L4. Rationale:

| Option | Verdict | Reasoning |
|--------|---------|-----------|
| Vanilla K8s NetworkPolicy | ❌ | Limited expressiveness, no cluster-wide policies |
| Cilium NetworkPolicy | ✅ | L3/L4 sufficient, cluster-wide policies, Hubble integration |
| Istio AuthorizationPolicy | ❌ | L7 complexity not needed, significant operational overhead |

---

## Two-Tier Model

Network policy is split into two tiers with different management approaches:

```
┌─────────────────────────────────────────────────────────────────┐
│                        PLATFORM TIER                            │
│  Hand-crafted CiliumNetworkPolicy per component                 │
│  High-touch, PR-reviewed, specific to each service              │
│                                                                 │
│  flux-system, prometheus, grafana, alertmanager, loki,          │
│  cert-manager, external-secrets, ingress-nginx, longhorn-system │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (well-defined interfaces)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      APPLICATION TIER                           │
│  Namespace-profile-based CiliumClusterwideNetworkPolicy         │
│  Low-touch, labels/annotations, composable                      │
│                                                                 │
│  All off-the-shelf apps, user workloads                         │
└─────────────────────────────────────────────────────────────────┘
```

### Platform Tier

Components in this tier receive individualized `CiliumNetworkPolicy` resources crafted per-component. Changes to these policies require PR review.

**Characteristics:**
- Policies are namespace-scoped (not cluster-wide)
- Explicit allow-lists for all ingress and egress
- No reliance on profiles or labels
- Written once, maintained as component evolves

### Application Tier

Workloads in this tier inherit network permissions from namespace-level annotations and labels. No per-app policy authoring required.

**Characteristics:**
- Namespace annotation selects a profile (set of permissions)
- Labels grant access to shared resources
- CCNPs match on annotations/labels to apply rules
- Onboarding = create namespace with correct metadata

---

## Application Tier: Profile System

### Profile Definitions

Profiles are pre-defined permission sets. A namespace selects exactly one profile.

| Profile | Egress Internet | Ingress External GW | Ingress Internal GW | Prometheus Scrape | Cross-NS |
|---------|-----------------|---------------------|---------------------|-------------------|----------|
| `isolated` | ❌ | ❌ | ❌ | ✅ | ❌ |
| `internal` | ❌ | ❌ | ✅ | ✅ | ❌ |
| `standard` | ✅ | ✅ | ✅ | ✅ | ❌ |
| `internal-egress` | ✅ | ❌ | ✅ | ✅ | ❌ |

**Profile descriptions:**

- **isolated**: Batch jobs, processors with no network needs beyond metrics scraping
- **internal**: Internal tools accessed only via internal gateway (Tailscale, etc.)
- **standard**: Typical web application with external exposure
- **internal-egress**: Services that call external APIs but aren't directly exposed

### Namespace Declaration

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: home-assistant
  annotations:
    network-policy.homelab/profile: "standard"
    network-policy.homelab/enforcement: "enabled"
  labels:
    access.network-policy.homelab/postgres: "true"
    access.network-policy.homelab/redis: "true"
```

### Universal Allowances

All application-tier namespaces automatically receive:

- **DNS egress**: All pods can reach CoreDNS for name resolution
- **Prometheus scrape ingress**: Monitoring can scrape metrics endpoints
- **Kubernetes API egress**: Pods can reach the API server (for service discovery, etc.)

These are baseline permissions that don't require profile selection.

---

## Shared Resource Access

Shared platform resources (databases, caches, object storage) use a label-based access model.

### Shared Resources

| Resource | Namespace | Port | Access Label |
|----------|-----------|------|--------------|
| PostgreSQL | `postgres` | 5432 | `access.network-policy.homelab/postgres` |
| Redis | `redis` | 6379 | `access.network-policy.homelab/redis` |
| Garage S3 | `garage` | 3900 | `access.network-policy.homelab/garage-s3` |
| MQTT | `mqtt` | 1883 | `access.network-policy.homelab/mqtt` |

### Access Pattern

For each shared resource, two CCNPs exist:

1. **Egress rule**: Allows app-tier namespaces with the access label to send traffic to the resource namespace/port
2. **Ingress rule**: Allows the resource namespace to receive traffic from namespaces with the access label

This ensures both directions are explicitly permitted.

### Credential Distribution

Network access labels authorize the *connection*. Authentication/authorization is handled separately via:
- Per-app credentials generated by secret-generator
- Distributed to app namespaces via external-secrets or similar

Network policy does not replace authentication - it adds defense in depth.

---

## Escape Hatch Mechanism

### Purpose

When a policy blocks legitimate traffic in production, operators need a fast recovery path that doesn't require policy debugging under pressure.

### Implementation

```yaml
annotations:
  network-policy.homelab/enforcement: "disabled"
```

When set to `disabled`:
- The default-deny CCNP excludes this namespace from its match
- Allow-rule CCNPs still apply (they're additive)
- Result: all traffic flows freely for this namespace

### Operational Workflow

1. **Incident**: App in namespace X cannot reach a required destination
2. **Immediate mitigation**: Set `enforcement: disabled` on namespace X
3. **Alert fires**: "Network policy enforcement disabled for namespace X" (must be configured)
4. **Traffic flows**: Immediate pressure relieved
5. **Post-incident**: Investigate root cause, update profile or add access label, re-enable enforcement

### Guardrails

- Disabling enforcement should trigger a monitoring alert
- The annotation should be treated as temporary - track via issue/ticket
- Consider adding a timestamp annotation for "disabled since" tracking

---

## Monitoring Namespace Breakout

The current `monitoring` namespace will be split into separate namespaces for tighter policy control:

| Current | New Namespace | Rationale |
|---------|---------------|-----------|
| Prometheus | `prometheus` | Needs wide scrape access, limited other access |
| Grafana | `grafana` | Needs ingress from users, egress to data sources |
| Alertmanager | `alertmanager` | Needs egress to notification targets |
| Loki | `loki` | Needs ingress from log shippers |

Each new namespace receives a hand-crafted platform-tier policy specific to its access needs.

---

## Platform Component Audit

Before implementation, each platform component must be audited for existing network policy support.

### Audit Checklist

| Component | Namespace | Has NP in Chart? | NP Type | Action |
|-----------|-----------|------------------|---------|--------|
| Flux | `flux-system` | | | |
| Prometheus | `prometheus` | | | |
| Grafana | `grafana` | | | |
| Alertmanager | `alertmanager` | | | |
| Loki | `loki` | | | |
| Cert-manager | `cert-manager` | | | |
| External-secrets | `external-secrets` | | | |
| Ingress-nginx | `ingress-nginx` | | | |
| Longhorn | `longhorn-system` | | | |
| PostgreSQL | `postgres` | | | |
| Redis | `redis` | | | |
| Garage | `garage` | | | |

### Audit Process

For each component:

1. **Check Helm chart values**: Look for `networkPolicy.enabled` or similar
2. **If policy exists**:
   - Is it Cilium-native or vanilla K8s NetworkPolicy?
   - Does it cover all required ingress/egress?
   - If K8s NetworkPolicy: evaluate upgrade to Cilium for consistency
3. **If no policy exists**: Create custom CiliumNetworkPolicy
4. **Document findings**: Record what the chart provides vs. what we supplement

### Action Categories

- **Use as-is**: Chart provides sufficient Cilium policy
- **Supplement**: Chart provides partial policy, add custom rules for gaps
- **Upgrade**: Chart provides K8s NetworkPolicy, convert to Cilium for consistency
- **Create**: Chart provides nothing, write full custom policy

---

## Discovery Workflow

For onboarding new applications, a discovery workflow helps determine the correct profile and access labels.

### High-Level Process

1. **Deploy app to dev cluster** with `enforcement: disabled`
2. **Run app through normal usage patterns** for a defined period (hours to days depending on app complexity)
3. **Collect Hubble flow data** for the app's namespace
4. **Analyze flows** to determine:
   - Does it need egress to internet?
   - Does it need ingress from gateways?
   - Which shared resources does it access?
5. **Map to profile**: Select the profile that matches observed needs
6. **Apply labels**: Add access labels for shared resources it contacted
7. **Enable enforcement**: Set `enforcement: enabled` and validate

### AI-Assisted Analysis

The discovery analysis can be delegated to an LLM with access to Hubble flow exports:

- Input: Hubble flow JSON/CSV for the namespace over the observation period
- Output: Recommended profile + access labels + any anomalies noted
- Human review: Validate recommendations before applying (distinguish "traffic that happened" from "traffic we want to permit")

### Hubble Data Collection

Hubble can export flows via:
- `hubble observe` CLI with filters
- Hubble UI flow export
- Hubble metrics (for aggregate patterns)

Specific collection procedures to be defined during implementation.

---

## Implementation Phases

### Phase 1: Foundation

- [ ] Break out `monitoring` namespace into `prometheus`, `grafana`, `alertmanager`, `loki`
- [ ] Define CCNP structure for application tier (default-deny, profile rules, access rules)
- [ ] Implement escape hatch logic in default-deny CCNP
- [ ] Create baseline CCNPs (DNS, Prometheus scrape, K8s API)

### Phase 2: Platform Tier

- [ ] Complete platform component audit
- [ ] Create or adopt policies for each platform component
- [ ] Validate platform components function correctly under policy

### Phase 3: Shared Resources

- [ ] Deploy PostgreSQL, Redis, Garage with platform-tier policies
- [ ] Implement access-label CCNPs for each shared resource
- [ ] Test access from labeled namespaces

### Phase 4: Application Tier Rollout

- [ ] Create profile CCNPs (isolated, internal, standard, internal-egress)
- [ ] Document onboarding process for new apps
- [ ] Migrate existing dev apps to profile-based enforcement
- [ ] Establish discovery workflow tooling

### Phase 5: Production Rollout

- [ ] Validate on dev/integration for sufficient soak period
- [ ] Apply to live cluster
- [ ] Monitor for blocked traffic, refine as needed

---

## Success Criteria

- All platform components have explicit network policies (no implicit allow-all)
- New application onboarding requires only namespace annotations/labels
- Blocked traffic is visible via Hubble/monitoring
- Escape hatch recovers a namespace in under 1 minute
- Access audit answers "who can talk to postgres?" with a single kubectl command


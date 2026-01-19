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

### CCNP Examples

**Default-Deny with Escape Hatch:**
```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/cilium.io/ciliumclusterwidenetworkpolicy_v2.json
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: default-deny
spec:
  description: "Default deny all traffic except for namespaces with enforcement disabled"
  endpointSelector:
    matchExpressions:
      # Exclude platform-tier namespaces (they have their own policies)
      - key: io.kubernetes.pod.namespace
        operator: NotIn
        values: ["kube-system", "flux-system", "prometheus", "grafana", "alertmanager", "loki", "cert-manager", "external-secrets", "longhorn-system", "istio-gateway", "istio-system"]
      # Exclude namespaces with enforcement disabled (escape hatch)
      - key: io.cilium.k8s.namespace.labels.network-policy\\.homelab/enforcement
        operator: NotIn
        values: ["disabled"]
  ingress:
    - {}  # Deny all by default (no fromEndpoints = deny)
  egress:
    - {}  # Deny all by default
```

**Profile: Standard (external + internal gateway access):**
```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: profile-standard
spec:
  description: "Allow ingress from both gateways, egress to internet"
  endpointSelector:
    matchLabels:
      io.cilium.k8s.namespace.labels.network-policy.homelab/profile: "standard"
  ingress:
    # Allow from external gateway
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: istio-gateway
            gateway.networking.k8s.io/gateway-name: external
    # Allow from internal gateway
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: istio-gateway
            gateway.networking.k8s.io/gateway-name: internal
  egress:
    # Allow egress to internet (non-cluster destinations)
    - toEntities:
        - world
    # Allow egress to cluster DNS
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
```

**Shared Resource Access (PostgreSQL):**
```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: access-postgres
spec:
  description: "Allow namespaces with postgres access label to reach PostgreSQL"
  endpointSelector:
    matchLabels:
      io.kubernetes.pod.namespace: postgres
      app.kubernetes.io/name: postgresql
  ingress:
    - fromEndpoints:
        - matchExpressions:
            - key: io.cilium.k8s.namespace.labels.access\\.network-policy\\.homelab/postgres
              operator: In
              values: ["true"]
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP
```

**DNS Baseline (all pods):**
```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: baseline-dns
spec:
  description: "Allow all pods to reach CoreDNS for name resolution"
  endpointSelector: {}  # All pods
  egress:
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
            - port: "53"
              protocol: TCP
```

**Prometheus Scrape Baseline:**
```yaml
apiVersion: cilium.io/v2
kind: CiliumClusterwideNetworkPolicy
metadata:
  name: baseline-prometheus-scrape
spec:
  description: "Allow Prometheus to scrape metrics from all pods"
  endpointSelector: {}  # All pods
  ingress:
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: prometheus
            app.kubernetes.io/name: prometheus
      toPorts:
        - ports:
            - port: "9090"
              protocol: TCP
            - port: "9091"
              protocol: TCP
            - port: "8080"
              protocol: TCP
            - port: "8443"
              protocol: TCP
```

### Universal Allowances

All application-tier namespaces automatically receive:

- **DNS egress**: All pods can reach CoreDNS for name resolution
- **Prometheus scrape ingress**: Monitoring can scrape metrics endpoints

**Kubernetes API access is NOT universal.** Pods requiring API access must explicitly opt-in:

```yaml
labels:
  access.network-policy.homelab/kube-api: "true"
```

This prevents arbitrary pods from reaching the API server, reducing the blast radius if a workload is compromised.

> **Security Note**: Unrestricted API access allows attackers to enumerate resources, check RBAC permissions, and potentially exploit misconfigurations. Default-deny for API access is defense in depth.

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

### Label Spoofing Mitigation

Access labels on namespaces could theoretically be spoofed if an attacker gains namespace modification permissions. Mitigations:

1. **RBAC restrictions**: Limit who can modify namespace labels (same as escape hatch RBAC)
2. **Admission controller**: Use Kyverno/OPA to validate label changes against an allowlist
3. **Audit logging**: Monitor namespace label changes for unauthorized modifications

```yaml
# Kyverno policy to restrict access label changes
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-network-access-labels
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: restrict-access-labels
      match:
        resources:
          kinds: ["Namespace"]
      validate:
        message: "Access labels can only be modified by platform team"
        deny:
          conditions:
            - key: "{{request.userInfo.groups}}"
              operator: AnyNotIn
              value: ["system:masters", "platform-team"]
```

> **Security Note**: Label-based access is convenient but relies on namespace metadata integrity. For highly sensitive resources, consider explicit CiliumNetworkPolicy rules instead of label-based CCNPs.

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

### RBAC Protection

The `network-policy.homelab/enforcement` annotation is security-sensitive. Restrict who can modify namespace annotations:

```yaml
# ClusterRole that excludes namespace annotation modification
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-viewer
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
    # Note: no "patch" or "update" - prevents annotation changes
```

For operators who need to disable enforcement during incidents, create a separate role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: network-policy-escape-hatch
  annotations:
    description: "Allows disabling network policy enforcement - incident response only"
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["patch"]
    # Audit log shows who used this capability
```

> **Security Note**: Without RBAC protection, any user with namespace annotation access can disable network policy enforcement. This should be restricted to SRE/platform team members.

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

### Migration Plan

**Prerequisites:**
- All monitoring components deployed via Flux HelmReleases
- PVCs use dynamic provisioning (Longhorn)

**Step 1: Create new namespaces (parallel)**
```bash
kubectl create namespace prometheus
kubectl create namespace grafana
kubectl create namespace alertmanager
kubectl create namespace loki
```

**Step 2: Update HelmRelease targetNamespace (via PR)**
```yaml
# Example: prometheus HelmRelease
spec:
  targetNamespace: prometheus  # Changed from: monitoring
```

**Step 3: Migrate PVCs (if stateful)**
For each stateful component:
1. Scale down deployment in old namespace
2. Create VolumeSnapshot from existing PVC
3. Create new PVC in new namespace from snapshot
4. Update HelmRelease to reference new PVC
5. Scale up in new namespace

**Step 4: Update cross-references**
- Grafana datasources pointing to Prometheus
- Alertmanager config in Prometheus
- Promtail/Vector shipping to Loki

**Step 5: Verify and cleanup**
```bash
# Verify all components healthy
kubectl get pods -n prometheus
kubectl get pods -n grafana
kubectl get pods -n alertmanager
kubectl get pods -n loki

# Delete old namespace after validation period (1 week)
kubectl delete namespace monitoring
```

**Rollback:** Revert HelmRelease targetNamespace changes via git revert.

---

## Platform Component Audit

Before implementation, each platform component must be audited for existing network policy support.

### Audit Checklist

| Component | Namespace | Has NP in Chart? | NP Type | Action |
|-----------|-----------|------------------|---------|--------|
| Flux | `flux-system` | No | N/A | **Create** - egress to GitHub, K8s API |
| Prometheus | `prometheus` | Yes | K8s NP | **Upgrade** - convert to Cilium for consistency |
| Grafana | `grafana` | Yes | K8s NP | **Upgrade** - add egress to datasources |
| Alertmanager | `alertmanager` | Yes | K8s NP | **Supplement** - add egress to notification targets |
| Loki | `loki` | Yes | K8s NP | **Upgrade** - convert to Cilium |
| Cert-manager | `cert-manager` | Yes | K8s NP | **Supplement** - add egress to ACME providers |
| External-secrets | `external-secrets` | No | N/A | **Create** - egress to AWS SSM |
| Ingress-nginx | `ingress-nginx` | Yes | K8s NP | **Upgrade** - not using, but document if needed |
| Longhorn | `longhorn-system` | No | N/A | **Create** - complex inter-component traffic |
| PostgreSQL | `postgres` | Yes | K8s NP | **Upgrade** - use Cilium for label-based access |
| Redis | `redis` | Yes | K8s NP | **Upgrade** - use Cilium for label-based access |
| Garage | `garage` | No | N/A | **Create** - S3 API ingress from labeled namespaces |

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

Hubble can export flows via CLI, UI, or metrics. Here are concrete collection procedures:

**CLI Collection (recommended for automation):**
```bash
# Collect all flows for a namespace over 1 hour
hubble observe --namespace home-assistant \
  --since 1h \
  --output jsonpb > /tmp/home-assistant-flows.json

# Filter to only egress flows (what the app is calling)
hubble observe --namespace home-assistant \
  --since 1h \
  --type l7 \
  --verdict FORWARDED \
  --output jsonpb > /tmp/home-assistant-egress.json

# Summary of unique destination IPs/ports
hubble observe --namespace home-assistant \
  --since 1h \
  --output json | jq -r '.destination.namespace + "/" + .destination.pod_name + ":" + (.l4.TCP.destination_port // .l4.UDP.destination_port | tostring)' | sort -u
```

**Analysis for Profile Selection:**
```bash
# Check for internet egress (non-RFC1918 destinations)
hubble observe --namespace home-assistant --since 1h --output json | \
  jq -r 'select(.destination.namespace == "") | .IP.destination' | \
  grep -vE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' | sort -u

# Check for gateway ingress (traffic from istio-gateway)
hubble observe --namespace home-assistant --since 1h --output json | \
  jq -r 'select(.source.namespace == "istio-gateway") | .destination.pod_name' | sort -u

# Check for shared resource access
hubble observe --namespace home-assistant --since 1h --output json | \
  jq -r 'select(.destination.namespace == "postgres" or .destination.namespace == "redis") | .destination.namespace' | sort -u
```

**Output Format for LLM Analysis:**
Export flows as CSV for easier LLM consumption:
```bash
hubble observe --namespace home-assistant --since 24h --output csv > flows.csv
# Columns: time,source_namespace,source_pod,dest_namespace,dest_pod,dest_port,verdict
```

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

- [ ] Validate on dev/integration until Flux reports healthy
- [ ] Apply to live cluster
- [ ] Monitor for blocked traffic, refine as needed

---

## Success Criteria

- All platform components have explicit network policies (no implicit allow-all)
- New application onboarding requires only namespace annotations/labels
- Blocked traffic is visible via Hubble/monitoring
- Escape hatch recovers a namespace in under 1 minute
- Access audit answers "who can talk to postgres?" with a single kubectl command


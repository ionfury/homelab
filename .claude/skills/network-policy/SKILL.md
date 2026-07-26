---
name: network-policy
description: |
  Manage Cilium network policies: profile selection, access labels, Hubble debugging,
  platform namespace CNPs, and emergency escape hatch procedures.

  Use when: (1) Deploying a new application and setting network profile,
  (2) Debugging blocked traffic with Hubble, (3) Adding shared resource access,
  (4) Creating platform namespace CNPs, (5) Using the escape hatch for emergencies.

  Triggers: "network policy", "hubble", "dropped traffic", "cilium", "blocked traffic",
  "network profile", "access label", "escape hatch", "cnp", "ccnp"
user-invocable: false
---

# Network Policy Management

Architecture quick reference: see [references/profiles.md](references/profiles.md#architecture-quick-reference)

See [references/profiles.md](references/profiles.md) for the full profile selection table, access label catalog, drop classification table, and Hubble command reference.

---

## Workflow: Deploy App with Network Policy

Choose a profile (see [references/profiles.md](references/profiles.md)) -> apply label to namespace -> add access labels for shared resources -> verify connectivity.

Apply profile label in `kubernetes/platform/namespaces.yaml` (committed to git, not `kubectl apply`):

```yaml
- name: my-app
  labels:
    network-policy.homelab/profile: standard
    access.network-policy.homelab/postgres: "true"     # if DB access needed
    access.network-policy.homelab/dragonfly: "true"    # if cache access needed
    access.network-policy.homelab/garage-s3: "true"    # if S3 access needed
    access.network-policy.homelab/kube-api: "true"     # if kube-api access needed
```

After deployment, check for drops:

```bash
hubble observe --verdict DROPPED --namespace my-app --since 5m
```

Run `scripts/hubble-debug.sh my-app 5m` for the full structured debug sequence.

---

## Workflow: Debug Blocked Traffic

Identify drops -> classify against [profiles.md drop table](references/profiles.md#drop-classification) -> verify specific flows with `scripts/hubble-debug.sh` -> check policy status:

```bash
kubectl get cnp -n my-app
kubectl get ccnp | grep -E 'baseline|profile'
kubectl get namespace my-app --show-labels | grep network-policy
```

---

## Workflow: Emergency Escape Hatch

**Use only when network policies block legitimate traffic and you need immediate relief.**

### Step 1: Disable Enforcement

```bash
kubectl label namespace <ns> network-policy.homelab/enforcement=disabled
```

This triggers alerts:
- `NetworkPolicyEnforcementDisabled` (warning) after 5 minutes
- `NetworkPolicyEnforcementDisabledLong` (critical) after 24 hours

### Step 2: Verify Traffic Flows

```bash
hubble observe --namespace <ns> --since 1m
```

### Step 3: Investigate Root Cause

Use the debug workflow above to identify the missing or misconfigured policy.

### Step 4: Fix the Policy (via GitOps)

Apply the fix through a PR.

### Step 5: Re-enable Enforcement

```bash
kubectl label namespace <ns> network-policy.homelab/enforcement-
```

See `docs/runbooks/network-policy-escape-hatch.md` for the full procedure.

---

## Workflow: Add Platform Namespace CNP

Platform namespaces need hand-crafted CNPs. Create in `kubernetes/platform/config/network-policy/platform/`.

Every platform CNP must include: DNS egress to `kube-system/kube-dns` (53 UDP/TCP), Prometheus scrape ingress from `monitoring`, health probe ingress from `health` entity and `169.254.0.0/16`, and HBONE rules (port 15008) if the namespace participates in the Istio mesh.

```yaml
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: <namespace>-default
  namespace: <namespace>
spec:
  description: "<Namespace purpose>: describe allowed traffic"
  endpointSelector: {}
  ingress:
    - fromEntities: [health]
    - fromCIDR: ["169.254.0.0/16"]
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: monitoring
            app.kubernetes.io/name: prometheus
      toPorts:
        - ports:
            - port: "<metrics-port>"
              protocol: TCP
    # HBONE (if mesh participant)
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: istio-system
            app: ztunnel
      toPorts:
        - ports:
            - port: "15008"
              protocol: TCP
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
    # HBONE (if mesh participant)
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: istio-system
            app: ztunnel
      toPorts:
        - ports:
            - port: "15008"
              protocol: TCP
```

After creating, add to `kubernetes/platform/config/network-policy/platform/kustomization.yaml`.

---

## Anti-Patterns

- **NEVER** create explicit `default-deny` policies — baselines provide implicit deny
- **NEVER** use profiles for platform namespaces — they need custom CNPs
- **NEVER** hardcode IP addresses — use endpoint selectors and entities
- **NEVER** allow `any` port — always specify explicit port lists
- **NEVER** disable enforcement without following the escape hatch runbook

---

## Cross-References

- [references/profiles.md](references/profiles.md) — Profile table, access labels, Hubble commands
- [network-policy/CLAUDE.md](../../kubernetes/platform/config/network-policy/CLAUDE.md) — Full architecture and directory structure
- [docs/runbooks/network-policy-escape-hatch.md](../../docs/runbooks/network-policy-escape-hatch.md) — Emergency bypass procedure

---
name: sre
description: |
  SRE debugging methodology for Kubernetes incident investigation, root cause analysis,
  and failure diagnosis.

  Use when: (1) Pods not starting, stuck, or failing (CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending),
  (2) Debugging Kubernetes errors or investigating "why is my pod...", (3) Service degradation or unavailability,
  (4) Root cause analysis for any Kubernetes incident, (5) Network policy blocking traffic,
  (6) Stalled HelmReleases or Flux failures that need troubleshooting.

  Triggers: "pod not starting", "pod stuck", "CrashLoopBackOff", "ImagePullBackOff", "OOMKilled",
  "Pending pod", "why is my pod", "kubernetes error", "k8s error", "service not available",
  "can't reach service", "debug kubernetes", "troubleshoot k8s", "what's wrong with my pod",
  "deployment not working", "helm install failed", "flux not reconciling", "root cause",
  "5 whys", "incident", "network policy blocking", "hubble dropped", "stalled helmrelease",
  "live not updating", "promotion pipeline stuck", "artifact not promoted"
user-invocable: false
---

> **Cluster access (`--context` patterns) and internal service URLs** are in the `k8s` skill.

# Debugging Kubernetes Incidents

## Core Principles

- **5 Whys Analysis** — NEVER stop at symptoms. Ask "why" until you reach the root cause.
- **Multi-Source Correlation** — Combine logs, events, metrics for a complete picture.
- **Zero Alert Tolerance** — Every firing alert must be addressed: fix the root cause, or as a last resort, create a declarative Silence CR with justification. Never ignore or defer.

## The 5 Whys Analysis (CRITICAL)

Apply 5 Whys before concluding any investigation. Stopping at symptoms leads to ineffective fixes.

**Example:**
```
Symptom: Helm install failed with "context deadline exceeded"

Why #1: Pods never became Ready
Why #2: Pods stuck in Pending state
Why #3: PVCs couldn't bind (StorageClass "fast" not found)
Why #4: longhorn-storage Kustomization failed to apply
Why #5: numberOfReplicas was integer instead of string

ROOT CAUSE: YAML type coercion issue
FIX: Use properly typed variable for StorageClass parameters
```

See [investigation-guide.md](investigation-guide.md) for red flags that you haven't reached root cause.

## Investigation Phases

**Phase 1 — Triage:** Confirm cluster (ask user: dev/integration/live) → assess severity (P1 down / P2 degraded / P3 minor) → identify scope.

**Phase 2 — Data Collection:** Use `scripts/cluster-health.sh [namespace]` for a quick snapshot. For targeted collection:

```bash
# Pod status and events
kubectl get pods -n <namespace>
kubectl describe pod <pod> -n <namespace>

# Logs (current and previous)
kubectl logs <pod> -n <namespace> --tail=100
kubectl logs <pod> -n <namespace> --previous

# Events timeline
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Resource usage
kubectl top pods -n <namespace>
```

Metrics and alerts (Prometheus is behind OAuth2 Proxy — DNS URLs won't work for API queries):

```bash
# Check firing alerts
kubectl --context <cluster> exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.state == "firing")'
```

**Phase 3 — Correlation:** Extract timestamps from logs, events, metrics → identify what happened FIRST → trace cascade.

**Phase 4 — Root Cause:** Apply 5 Whys. Validate: temporal (before symptom?), causal (logically explains it?), evidence (supporting data?), complete (asked "why" enough times?).

**Phase 5 — Remediation:** Use AskUserQuestion when multiple valid approaches exist. Provide recommendations only (read-only on integration/live):
- Immediate: rollback, scale, restart
- Permanent: code/config fixes
- Prevention: alerts, quotas, tests

For symptom → first check → common cause mapping, see [investigation-guide.md](investigation-guide.md).

## Network Policy Debugging (Cilium + Hubble)

All traffic is implicitly denied. Missing labels are the most common cause of blocked traffic.

```bash
# Setup Hubble access (run once per session)
kubectl --context <cluster> port-forward -n kube-system svc/hubble-relay 4245:80 &

# See dropped traffic in a namespace
hubble observe --verdict DROPPED --namespace <namespace> --since 5m

# Check specific traffic flow
hubble observe --from-namespace <source> --to-namespace <dest> --since 5m
```

Check namespace labels:
```bash
kubectl --context <cluster> get ns <namespace> -o jsonpath='{.metadata.labels}' | jq
# Required: network-policy.homelab/profile: standard|internal|internal-egress|isolated
# Optional: access.network-policy.homelab/postgres|garage-s3|kube-api: "true"
```

Emergency escape hatch (triggers alert after 5m):
```bash
kubectl --context <cluster> label namespace <ns> network-policy.homelab/enforcement=disabled
# Re-enable after fixing:
kubectl --context <cluster> label namespace <ns> network-policy.homelab/enforcement-
```

See `docs/runbooks/network-policy-escape-hatch.md` for full procedure.

## Kickstarting Stalled HelmReleases

HelmReleases can get stuck in `Stalled/RetriesExceeded` even after the underlying issue is
resolved. Suspend and resume to reset the failure counter:

```bash
flux --context <cluster> suspend helmrelease <name> -n flux-system
flux --context <cluster> resume helmrelease <name> -n flux-system
```

Common self-healed causes: missing Secret/ConfigMap (ExternalSecret eventually created it),
missing CRD, transient image pull failure, temporary resource quota exceeded. Ensure proper
`dependsOn` ordering to prevent recurrence.

## Promotion Pipeline Debugging

**Symptom: "Live cluster not updating after merge"**

Walk through each stage in order — see [investigation-guide.md](investigation-guide.md) for
the failure mode table. Quick diagnostic flow:

```
1. PR merged → did build-platform-artifact.yaml trigger?
   └─ If not: was kubernetes/ modified? (paths filter)

2. OCI artifact in GHCR?
   └─ flux list artifact oci://ghcr.io/<repo>/platform | grep integration

3. Integration OCIRepository seeing new version?
   └─ kubectl --context integration get ocirepository -n flux-system
   └─ Semver constraint must be ">= 0.0.0-0" to accept RCs

4. Integration Kustomization healthy?
   └─ flux --context integration get kustomizations -n flux-system

5. Flux Alert fired repository_dispatch?
   └─ kubectl --context integration describe alert validation-success -n flux-system

6. tag-validated-artifact.yaml ran?
   └─ GitHub Actions → "Tag Validated Artifact" workflow

7. Live OCIRepository seeing stable semver?
   └─ kubectl --context live get ocirepository -n flux-system
   └─ Semver constraint must be ">= 0.0.0" (stable only, no RCs)
```

See `.github/CLAUDE.md` for full pipeline architecture and rollback procedures.

## Keywords

kubernetes, debugging, crashloopbackoff, oomkilled, pending, root cause analysis, 5 whys, incident investigation, pod logs, events, troubleshooting, network policy, hubble, stalled helmrelease, promotion pipeline, live not updating

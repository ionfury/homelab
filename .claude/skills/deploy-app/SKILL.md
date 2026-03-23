---
name: deploy-app
description: |
  End-to-end application deployment orchestration for the Kubernetes homelab.
  Covers research, worktree setup, Flux ResourceSet configuration, dev cluster testing,
  monitoring integration, and PR creation.

  Use when: (1) Deploying a new application to the cluster, (2) Adding a new Helm release to the platform,
  (3) Setting up monitoring, alerting, and health checks for a new service, (4) Testing deployment on
  dev cluster before GitOps promotion.

  Triggers: "deploy app", "add new application", "deploy to kubernetes", "install helm chart",
  "/deploy-app", "set up new service", "add monitoring for", "deploy with monitoring"
user-invocable: false
---

# Deploy App Workflow

End-to-end orchestration for deploying applications to the Kubernetes homelab with full monitoring integration.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      /deploy-app Workflow                           │
├─────────────────────────────────────────────────────────────────────┤
│  1. RESEARCH                                                        │
│     ├─ Invoke kubesearch skill for real-world patterns              │
│     ├─ Check if native Helm chart exists (helm search hub)          │
│     ├─ Determine: native chart vs app-template                      │
│     └─ AskUserQuestion: Present findings, confirm approach          │
│                                                                     │
│  2. SETUP                                                           │
│     └─ task wt:new -- deploy-<app-name>                             │
│                                                                     │
│  3. CONFIGURE (in worktree)                                         │
│     ├─ kubernetes/platform/versions.env (add version)               │
│     ├─ kubernetes/platform/namespaces.yaml (add namespace)          │
│     ├─ kubernetes/platform/helm-charts.yaml (add input)             │
│     ├─ kubernetes/platform/charts/<app>.yaml (create values)        │
│     ├─ kubernetes/platform/kustomization.yaml (register)            │
│     └─ kubernetes/platform/config/<app>/ (optional extras)          │
│        ├─ route.yaml, canary.yaml, prometheus-rules.yaml            │
│                                                                     │
│  4. VALIDATE: task k8s:validate && task renovate:validate           │
│                                                                     │
│  5. TEST ON DEV (direct helm install, bypass Flux)                  │
│     ├─ Wait for pods ready, verify network + monitoring             │
│     └─ AskUserQuestion: Report status, confirm proceed              │
│                                                                     │
│  6. CLEANUP & PR                                                    │
│     ├─ helm uninstall, Flux reconcile-validate, commit, PR          │
│     └─ Report PR URL to user                                        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Research

Invoke the kubesearch skill to find real-world chart configurations: `/kubesearch <chart-name>`

Check for a native chart: `helm search hub <app-name> --max-col-width=100`

| Scenario | Approach |
|----------|----------|
| Official/community chart exists | Use native Helm chart |
| Only container image available | Use app-template |
| Chart is unmaintained (>1 year) | Consider app-template |

Use AskUserQuestion to confirm: chart selection, exposure type (internal/external/none), namespace, persistence requirements.

---

## Phase 2: Setup

Create an isolated worktree: `task wt:new -- deploy-<app-name>`

This creates branch `deploy-<app-name>` and worktree `../homelab-deploy-<app-name>/`. Work exclusively in the worktree.

---

## Phase 3: Configure

### 3.1 Add Version to versions.env

Add a version entry with a Renovate annotation. For annotation syntax and datasource selection, see the [versions-renovate skill](../versions-renovate/SKILL.md).

### 3.2 Add Namespace to namespaces.yaml

Add to `kubernetes/platform/namespaces.yaml` inputs array:

```yaml
- name: <namespace>
  dataplane: ambient
  security: baseline       # restricted | baseline | privileged
  networkPolicy: false     # or object with profile/enforcement
```

**PodSecurity level:**

| Level | Use When |
|-------|----------|
| `restricted` | Standard controllers, databases, simple apps — requires full security context on all containers |
| `baseline` | Apps needing elevated capabilities (e.g., `NET_BIND_SERVICE`) |
| `privileged` | Host access, BPF, device access |

**Network policy profile:**

| Profile | Use When |
|---------|----------|
| `isolated` | No inbound traffic needed |
| `internal` | Internal gateway only |
| `internal-egress` | Internal + calls external APIs |
| `standard` | Public-facing (both gateways + HTTPS egress) |

**Access labels** (add as needed):

```yaml
    access.network-policy.homelab/postgres: "true"
    access.network-policy.homelab/garage-s3: "true"
    access.network-policy.homelab/kube-api: "true"
```

For PostgreSQL provisioning, see the [cnpg-database skill](../cnpg-database/SKILL.md).

### 3.3 Add to helm-charts.yaml

Add to `kubernetes/platform/helm-charts.yaml` inputs array:

```yaml
- name: "<app-name>"
  namespace: "<namespace>"
  chart:
    name: "<chart-name>"
    version: "${<APP>_VERSION}"
    url: "https://charts.example.com"  # or oci://registry.io/path
  dependsOn: [cilium]
```

### 3.4 Create Values File

Create `kubernetes/platform/charts/<app-name>.yaml`. See [references/file-templates.md](references/file-templates.md) for complete templates.

**Security context for `restricted` namespaces** (cert-manager, external-secrets, system, database, kromgo): add full restricted context to all containers. `task k8s:validate` does NOT catch PodSecurity violations — only admission time reveals them.

```yaml
# Pod-level
podSecurityContext:       # key varies by chart
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

# Container-level (every container and init container)
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault
```

Check the image's default user — if it runs as root, add `runAsUser: 65534`.

### 3.5 Register in kustomization.yaml

Add to `kubernetes/platform/kustomization.yaml` configMapGenerator files list: `- charts/<app-name>.yaml`

### 3.6 Configure Renovate Tracking

Renovate tracks versions.env entries automatically via inline `# renovate:` annotations added in step 3.1. No changes to `.github/renovate.json5` are needed unless adding grouping or automerge overrides. See the [versions-renovate skill](../versions-renovate/SKILL.md).

### 3.7 Optional: Additional Configuration

Create `kubernetes/platform/config/<app-name>/` for extra resources. See [references/file-templates.md](references/file-templates.md) for HTTPRoute, secret, and ExternalSecret templates. See [references/monitoring-patterns.md](references/monitoring-patterns.md) for Canary, PrometheusRule, and Grafana dashboard examples.

For gateway routing and TLS, see the [gateway-routing skill](../gateway-routing/SKILL.md).

---

## Phase 4: Validate

`task k8s:validate` → `task renovate:validate`. Fix all errors before proceeding.

---

## Phase 5: Test on Dev

The dev cluster is a sandbox — iterate freely.

**Deploy directly** (suspend Flux first if needed: `task k8s:flux-suspend -- <kustomization-name>`):

```bash
helm install <app-name> <repo>/<chart> \
  -n <namespace> --create-namespace \
  -f kubernetes/platform/charts/<app-name>.yaml \
  --version <version>

kubectl -n <namespace> \
  wait --for=condition=Ready pod -l app.kubernetes.io/name=<app-name> --timeout=300s
```

For OCI charts, use `oci://registry/<path>/<chart>`. For iteration, use `helm upgrade` instead of `helm install`.

**Verify network connectivity** (CRITICAL — network policies are enforced):

```bash
kubectl port-forward -n kube-system svc/hubble-relay 4245:80 &
hubble observe --verdict DROPPED --namespace <namespace> --since 5m
hubble observe --from-namespace istio-gateway --to-namespace <namespace> --since 2m
hubble observe --from-namespace <namespace> --to-namespace database --since 2m
```

Common causes: missing profile label (gateway blocked), missing access label (database/S3 blocked), wrong profile (external API calls blocked).

**Verify monitoring** using the helper scripts:

```bash
.claude/skills/deploy-app/scripts/check-deployment-health.sh <namespace> <app-name>
.claude/skills/deploy-app/scripts/check-servicemonitor.sh <app-name>
.claude/skills/deploy-app/scripts/check-alerts.sh
.claude/skills/deploy-app/scripts/check-canary.sh <app-name>  # if canary created
```

Iterate until all checks pass. AskUserQuestion to report status and confirm proceeding.

---

## Phase 6: Validate GitOps & PR

Uninstall direct helm install → reconcile via Flux → validate clean convergence:

```bash
helm uninstall <app-name> -n <namespace>
task k8s:reconcile-validate
```

If reconciliation fails, fix manifests and retry.

Commit using conventional commits format, push, and create the PR:

```bash
git push -u origin deploy-<app-name>
gh pr create --title "feat(k8s): deploy <app-name>" --body "..."
```

The worktree is kept until PR is merged. User cleans up with `task wt:remove -- deploy-<app-name>`.

---

## Secrets Handling

For detailed workflows, see the [secrets skill](../secrets/SKILL.md).

```
App needs a secret?
├─ Random/generated → secret-generator annotation
│     secret-generator.v1.mittwald.de/autogenerate: "key"
├─ External service (OAuth, third-party API) → ExternalSecret → AWS SSM
└─ Unclear → AskUserQuestion: "Can this be randomly generated?"
```

---

## Error Handling

| Error | Response |
|-------|----------|
| No chart found | Suggest app-template, ask user |
| Validation fails | Show error, fix, retry |
| CrashLoopBackOff | Show logs, propose fix, ask user |
| Alerts firing | Show alerts, determine if related, ask user |
| Namespace exists | Ask user: reuse or new name |
| Secret needed | Apply decision tree above |
| Pods rejected by PodSecurity | Add restricted security context (see step 3.4) |

---

## References

- [File Templates](references/file-templates.md) - Copy-paste templates for all config files
- [Monitoring Patterns](references/monitoring-patterns.md) - ServiceMonitor, PrometheusRule, Canary examples
- [flux-gitops skill](../flux-gitops/SKILL.md) - ResourceSet patterns
- [app-template skill](../app-template/SKILL.md) - For apps without native charts
- [kubesearch skill](../kubesearch/SKILL.md) - Research workflow

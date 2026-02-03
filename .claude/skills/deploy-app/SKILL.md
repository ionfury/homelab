---
name: deploy-app
description: |
  End-to-end application deployment orchestration for the Kubernetes homelab.

  Use when: (1) Deploying a new application to the cluster, (2) Adding a new Helm release to the platform,
  (3) Setting up monitoring, alerting, and health checks for a new service, (4) Research before deploying,
  (5) Testing deployment on dev cluster before GitOps promotion.

  Triggers: "deploy app", "add new application", "deploy to kubernetes", "install helm chart",
  "/deploy-app", "set up new service", "add monitoring for", "deploy with monitoring"
user_invocable: true
---

# Deploy App Workflow

End-to-end orchestration for deploying applications to the Kubernetes homelab with full monitoring integration.

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                      /deploy-app Workflow                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. RESEARCH                                                        │
│     ├─ Invoke kubesearch skill for real-world patterns              │
│     ├─ Check if native Helm chart exists (helm search hub)          │
│     ├─ Determine: native chart vs app-template                      │
│     └─ AskUserQuestion: Present findings, confirm approach          │
│                                                                      │
│  2. SETUP                                                           │
│     └─ task wt:new -- deploy-<app-name>                             │
│        (Creates isolated worktree + branch)                         │
│                                                                      │
│  3. CONFIGURE (in worktree)                                         │
│     ├─ kubernetes/platform/versions.env (add version)               │
│     ├─ kubernetes/platform/namespaces.yaml (add namespace)          │
│     ├─ kubernetes/platform/helm-charts.yaml (add input)             │
│     ├─ kubernetes/platform/charts/<app>.yaml (create values)        │
│     ├─ kubernetes/platform/kustomization.yaml (register)            │
│     ├─ .github/renovate.json5 (add manager)                         │
│     └─ kubernetes/platform/config/<app>/ (optional extras)          │
│        ├─ route.yaml (HTTPRoute if exposed)                         │
│        ├─ canary.yaml (health checks)                               │
│        ├─ prometheus-rules.yaml (custom alerts)                     │
│        └─ dashboard.yaml (Grafana ConfigMap)                        │
│                                                                      │
│  4. VALIDATE                                                        │
│     ├─ task k8s:validate                                            │
│     └─ task renovate:validate                                       │
│                                                                      │
│  5. TEST ON DEV (bypass Flux)                                       │
│     ├─ helm install directly to dev cluster                         │
│     ├─ Wait for pods ready (kubectl wait)                           │
│     ├─ Verify ServiceMonitor discovered (Prometheus API)            │
│     ├─ Verify no new alerts firing                                  │
│     ├─ Verify canary passing (if created)                           │
│     └─ AskUserQuestion: Report status, confirm proceed              │
│                                                                      │
│  6. CLEANUP & PR                                                    │
│     ├─ helm uninstall from dev                                      │
│     ├─ git commit (conventional commit format)                      │
│     ├─ git push + gh pr create                                      │
│     └─ Report PR URL to user                                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Research

### 1.1 Search Kubesearch for Real-World Examples

Invoke the kubesearch skill to find how other homelabs configure this chart:

```
/kubesearch <chart-name>
```

This provides:
- Common configuration patterns
- Values.yaml examples from production homelabs
- Gotchas and best practices

### 1.2 Check for Native Helm Chart

```bash
helm search hub <app-name> --max-col-width=100
```

Decision matrix:

| Scenario | Approach |
|----------|----------|
| Official/community chart exists | Use native Helm chart |
| Only container image available | Use app-template |
| Chart is unmaintained (>1 year) | Consider app-template |
| User preference for app-template | Use app-template |

### 1.3 User Confirmation

Use AskUserQuestion to present findings and confirm:

- Chart selection (native vs app-template)
- Exposure type: internal, external, or none
- Namespace selection (new or existing)
- Persistence requirements

---

## Phase 2: Setup

### 2.1 Create Worktree

All deployment work happens in an isolated worktree:

```bash
task wt:new -- deploy-<app-name>
```

This creates:
- Branch: `deploy-<app-name>`
- Worktree: `../homelab-deploy-<app-name>/`

### 2.2 Change to Worktree

```bash
cd ../homelab-deploy-<app-name>
```

All subsequent file operations happen in the worktree.

---

## Phase 3: Configure

### 3.1 Add Version to versions.env

```bash
# kubernetes/platform/versions.env
<APP>_VERSION="x.y.z"
```

### 3.2 Add Namespace to namespaces.yaml

Add to `kubernetes/platform/namespaces.yaml` inputs array:

```yaml
- name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: baseline
```

### 3.3 Add to helm-charts.yaml

Add to `kubernetes/platform/helm-charts.yaml` inputs array:

```yaml
- name: "<app-name>"
  namespace: "<namespace>"
  chart:
    name: "<chart-name>"
    version: "${<APP>_VERSION}"
    url: "https://charts.example.com"  # or oci://registry.io/path
  dependsOn: [cilium]  # Adjust based on dependencies
```

For OCI registries:
```yaml
    url: "oci://ghcr.io/org/helm"
```

### 3.4 Create Values File

Create `kubernetes/platform/charts/<app-name>.yaml`:

```yaml
# yaml-language-server: $schema=<schema-url-if-available>
---
# Helm values for <app-name>
# Based on kubesearch research and best practices

# Enable monitoring
serviceMonitor:
  enabled: true

# Use internal domain for ingress
ingress:
  enabled: true
  hosts:
    - host: <app-name>.${internal_domain}
```

See [references/file-templates.md](references/file-templates.md) for complete templates.

### 3.5 Register in kustomization.yaml

Add to `kubernetes/platform/kustomization.yaml` configMapGenerator:

```yaml
configMapGenerator:
  - name: platform-values
    files:
      # ... existing
      - charts/<app-name>.yaml
```

### 3.6 Add Renovate Manager

Add to `.github/renovate.json5` customManagers:

```json5
{
  customType: "regex",
  fileMatch: ["kubernetes/platform/versions\\.env$"],
  matchStrings: ["<APP>_VERSION=\"(?<currentValue>[^\"]+)\""],
  depNameTemplate: "<chart-name>",
  packageNameTemplate: "<registry-path>",
  datasourceTemplate: "helm"  // or "docker" for OCI
}
```

### 3.7 Optional: Additional Configuration

For apps that need extra resources, create `kubernetes/platform/config/<app-name>/`:

#### HTTPRoute (for exposed apps)

```yaml
# config/<app-name>/route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: <app-name>
spec:
  parentRefs:
    - name: internal-gateway
      namespace: gateway
  hostnames:
    - <app-name>.${internal_domain}
  rules:
    - backendRefs:
        - name: <app-name>
          port: 80
```

#### Canary Health Check

```yaml
# config/<app-name>/canary.yaml
apiVersion: canaries.flanksource.com/v1
kind: Canary
metadata:
  name: http-check-<app-name>
spec:
  schedule: "@every 1m"
  http:
    - name: <app-name>-health
      url: https://<app-name>.${internal_domain}/health
      responseCodes: [200]
      maxSSLExpiry: 7
```

#### PrometheusRule (custom alerts)

Only create if the chart doesn't include its own alerts:

```yaml
# config/<app-name>/prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: <app-name>-alerts
spec:
  groups:
    - name: <app-name>.rules
      rules:
        - alert: <AppName>Down
          expr: up{job="<app-name>"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "<app-name> is down"
```

#### Grafana Dashboard

1. Search grafana.com for community dashboards
2. Add via gnetId in grafana values, OR
3. Create ConfigMap:

```yaml
# config/<app-name>/dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-<app-name>
  labels:
    grafana_dashboard: "true"
  annotations:
    grafana_folder: "Applications"
data:
  <app-name>.json: |
    { ... dashboard JSON ... }
```

See [references/monitoring-patterns.md](references/monitoring-patterns.md) for detailed examples.

---

## Phase 4: Validate

### 4.1 Kubernetes Validation

```bash
task k8s:validate
```

This runs:
- kustomize build
- kubeconform schema validation
- yamllint checks

### 4.2 Renovate Validation

```bash
task renovate:validate
```

Fix any errors before proceeding.

---

## Phase 5: Test on Dev

### 5.1 Direct Helm Install

Bypass Flux to test immediately on dev cluster:

```bash
# Get values from rendered kustomization
KUBECONFIG=~/.kube/dev.yaml helm install <app-name> <repo>/<chart> \
  -n <namespace> --create-namespace \
  -f kubernetes/platform/charts/<app-name>.yaml \
  --version <version>
```

For OCI charts:
```bash
KUBECONFIG=~/.kube/dev.yaml helm install <app-name> oci://registry/<path>/<chart> \
  -n <namespace> --create-namespace \
  -f kubernetes/platform/charts/<app-name>.yaml \
  --version <version>
```

### 5.2 Wait for Pods

```bash
KUBECONFIG=~/.kube/dev.yaml kubectl -n <namespace> \
  wait --for=condition=Ready pod -l app.kubernetes.io/name=<app-name> --timeout=300s
```

### 5.3 Verify Monitoring

Use the helper scripts:

```bash
# Check deployment health
.claude/skills/deploy-app/scripts/check-deployment-health.sh <namespace> <app-name>

# Check ServiceMonitor discovery (requires port-forward)
.claude/skills/deploy-app/scripts/check-servicemonitor.sh <app-name>

# Check no new alerts
.claude/skills/deploy-app/scripts/check-alerts.sh

# Check canary status (if created)
.claude/skills/deploy-app/scripts/check-canary.sh <app-name>
```

### 5.4 User Confirmation

Use AskUserQuestion to report:
- Pod status (Ready/NotReady)
- ServiceMonitor discovery status
- Alert status
- Canary status (if applicable)

Ask whether to proceed with PR creation.

---

## Phase 6: Cleanup & PR

### 6.1 Uninstall from Dev

```bash
KUBECONFIG=~/.kube/dev.yaml helm uninstall <app-name> -n <namespace>
```

### 6.2 Commit Changes

```bash
git add -A
git commit -m "feat(k8s): deploy <app-name> to platform

- Add <app-name> HelmRelease via ResourceSet
- Configure monitoring (ServiceMonitor, alerts)
- Add Renovate manager for version updates
$([ -f kubernetes/platform/config/<app-name>/canary.yaml ] && echo "- Add canary health checks")
$([ -f kubernetes/platform/config/<app-name>/route.yaml ] && echo "- Configure HTTPRoute for ingress")"
```

### 6.3 Push and Create PR

```bash
git push -u origin deploy-<app-name>

gh pr create --title "feat(k8s): deploy <app-name>" --body "$(cat <<'EOF'
## Summary
- Deploy <app-name> to the Kubernetes platform
- Full monitoring integration (ServiceMonitor + alerts)
- Automated version updates via Renovate

## Test plan
- [ ] Validated with `task k8s:validate`
- [ ] Tested on dev cluster with direct helm install
- [ ] ServiceMonitor targets discovered by Prometheus
- [ ] No new alerts firing
- [ ] Canary health checks passing (if applicable)

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 6.4 Report PR URL

Output the PR URL for the user.

**Note**: The worktree is intentionally kept until PR is merged. User cleans up with:
```bash
task wt:remove -- deploy-<app-name>
```

---

## Secrets Handling

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Secrets Decision Tree                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  App needs a secret?                                                │
│      │                                                              │
│      ├─ Random/generated (password, API key, encryption key)        │
│      │   └─ Use secret-generator annotation:                        │
│      │      secret-generator.v1.mittwald.de/autogenerate: "key"     │
│      │                                                              │
│      ├─ External service (OAuth, third-party API)                   │
│      │   └─ Create ExternalSecret → AWS SSM                         │
│      │      Instruct user to add secret to Parameter Store          │
│      │                                                              │
│      └─ Unclear which type?                                         │
│          └─ AskUserQuestion: "Can this be randomly generated?"      │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Auto-Generated Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <app-name>-secret
  annotations:
    secret-generator.v1.mittwald.de/autogenerate: "password,api-key"
type: Opaque
```

### External Secrets

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <app-name>-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: aws-parameter-store
  target:
    name: <app-name>-secret
  data:
    - secretKey: api-token
      remoteRef:
        key: /homelab/kubernetes/${cluster_name}/<app-name>/api-token
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
| Port-forward fails | Check if Prometheus is running in dev |

---

## User Interaction Points

| Phase | Interaction | Purpose |
|-------|-------------|---------|
| Research | AskUserQuestion | Present kubesearch findings, confirm chart choice |
| Research | AskUserQuestion | Native helm vs app-template decision |
| Research | AskUserQuestion | Exposure type (internal/external/none) |
| Dev Test | AskUserQuestion | Report test results, confirm PR creation |
| Failure | AskUserQuestion | Report error, propose fix, ask to retry |

---

## References

- [File Templates](references/file-templates.md) - Copy-paste templates for all config files
- [Monitoring Patterns](references/monitoring-patterns.md) - ServiceMonitor, PrometheusRule, Canary examples
- [flux-gitops skill](../flux-gitops/SKILL.md) - ResourceSet patterns
- [app-template skill](../app-template/SKILL.md) - For apps without native charts
- [kubesearch skill](../kubesearch/SKILL.md) - Research workflow

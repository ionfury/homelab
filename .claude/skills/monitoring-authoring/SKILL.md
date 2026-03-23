---
name: monitoring-authoring
description: |
  Author monitoring resources: PrometheusRules, ServiceMonitors, PodMonitors,
  AlertmanagerConfig, Silence CRs, and canary-checker health checks.

  Use when: (1) Creating or modifying alert rules (PrometheusRule), (2) Adding scrape targets
  (ServiceMonitor/PodMonitor), (3) Configuring Alertmanager routing or silences,
  (4) Writing canary-checker health checks, (5) Creating recording rules,
  (6) Adding monitoring for a new application or platform component.

  Triggers: "create alert", "add alerting", "PrometheusRule", "ServiceMonitor", "PodMonitor",
  "AlertmanagerConfig", "silence alert", "canary check", "recording rule", "add monitoring",
  "scrape target", "alert rule", "prometheus rule", "health check canary"
user-invocable: false
---

# Monitoring Resource Authoring

This skill covers **creating and modifying** monitoring resources. For **querying** Prometheus
or investigating alerts, see the [prometheus skill](../prometheus/SKILL.md) and
[sre skill](../sre/SKILL.md).

## Resource Types

| Resource | API Group | Purpose |
|----------|-----------|---------|
| `PrometheusRule` | `monitoring.coreos.com/v1` | Alert rules and recording rules |
| `ServiceMonitor` | `monitoring.coreos.com/v1` | Scrape metrics from Services |
| `PodMonitor` | `monitoring.coreos.com/v1` | Scrape metrics from Pods directly |
| `ScrapeConfig` | `monitoring.coreos.com/v1alpha1` | Advanced scrape configuration |
| `AlertmanagerConfig` | `monitoring.coreos.com/v1alpha1` | Routing, receivers, silencing |
| `Silence` | `observability.giantswarm.io/v1alpha2` | Declarative Alertmanager silences |
| `Canary` | `canaries.flanksource.com/v1` | Synthetic health checks (HTTP, TCP, K8s) |

See [references/file-placement.md] for where to put each resource type and naming conventions.

---

## PrometheusRule Authoring

Every PrometheusRule must include `release: kube-prometheus-stack` label for Prometheus to discover it.

PrometheusRule template: see [references/alert-patterns.md](references/alert-patterns.md#prometheusrule-template)

### Severity and `for` Duration

| Severity | `for` Duration | Use Case | Routing |
|----------|----------------|----------|---------|
| `critical` | 2m-5m | Service down, data loss risk | Discord |
| `warning` | 5m-15m | Degraded performance, limits | Discord |
| `info` | 10m-30m | Informational, non-urgent | Silenced by InfoInhibitor |

Guidelines: `for: 0m` only for instant failures (e.g., SMART fail). Most alerts: 5m default. Flap-prone metrics (error rates, latency): 10m-15m. Use 5m for absence detection.

### Alert Grouping

Group related alerts in named rule groups — affects Prometheus UI ordering:

```yaml
spec:
  groups:
    - name: cilium-agent       # Agent availability and health
      rules: [...]
    - name: cilium-bpf         # BPF subsystem alerts
      rules: [...]
```

See [references/alert-patterns.md] for common alert patterns (down, error rate, latency, capacity, PVC), annotation template functions, and recording rule examples.

---

## ServiceMonitor and PodMonitor

### Via Helm Values (Preferred)

```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
```

### Manual ServiceMonitor

Place in `monitoring` namespace; use `namespaceSelector` to reach target namespace. Required label: `release: kube-prometheus-stack`.

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/monitoring.coreos.com/servicemonitor_v1.json
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: <component>
  namespace: monitoring
  labels:
    release: kube-prometheus-stack    # REQUIRED
spec:
  namespaceSelector:
    matchNames: [<target-namespace>]
  selector:
    matchLabels:
      app.kubernetes.io/name: <component>
  endpoints:
    - port: http-monitoring
      path: /metrics
      interval: 30s
```

### Manual PodMonitor

Use when pods expose metrics but don't have a Service (DaemonSets, sidecars). Same pattern as ServiceMonitor with `podMetricsEndpoints` instead of `endpoints`, and numeric ports quoted: `port: "15020"`. For `matchExpressions` selecting multiple values, see any existing Flux PodMonitor in `config/monitoring/`.

See [references/alertmanagerconfig-reference.md] for AlertmanagerConfig routing, Silence CR templates, and matcher reference.

---

## Canary Health Checks

Canary resources live in `config/canary-checker/` (platform) or alongside app config.

**HTTP health check:**
```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/canaries.flanksource.com/canary_v1.json
apiVersion: canaries.flanksource.com/v1
kind: Canary
metadata:
  name: http-check-<component>
spec:
  schedule: "@every 1m"
  http:
    - name: <component>-health
      url: https://<component>.${internal_domain}/health
      responseCodes: [200]
      maxSSLExpiry: 7
      thresholdMillis: 5000
```

**Kubernetes resource check with CEL** (preferred over `ready: true` — avoids penalizing pods with restart history):
```yaml
spec:
  interval: 60
  kubernetes:
    - name: <component>-pods-healthy
      kind: Pod
      namespaceSelector:
        name: <namespace>
      resource:
        labelSelector: app.kubernetes.io/name=<component>
      test:
        expr: >
          dyn(results).all(pod,
            pod.Object.status.phase == "Running" &&
            pod.Object.status.conditions.exists(c, c.type == "Ready" && c.status == "True")
          )
```

`canary_check == 1` triggers `CanaryCheckFailure` (critical, 2m). No per-canary alert needed.

---

## Workflow: Adding Monitoring for a New Component

Check if the chart provides monitoring via Helm values first (`kubesearch <chart-name> serviceMonitor`) → enable via values if available → else create ServiceMonitor/PodMonitor + PrometheusRule + Canary manually → place in correct directory → register in kustomization → `task k8s:validate` → verify after deployment:

```bash
# Check ServiceMonitor is discovered
KUBECONFIG=~/.kube/<cluster>.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/targets' | \
  jq '.data.activeTargets[] | select(.labels.job | contains("<component>"))'

# Check alert rules are loaded
KUBECONFIG=~/.kube/<cluster>.yaml kubectl exec -n monitoring prometheus-kube-prometheus-stack-0 -c prometheus -- \
  wget -qO- 'http://localhost:9090/api/v1/rules' | \
  jq '.data.groups[] | select(.name | contains("<component>"))'
```

For PrometheusRule validation before committing, see [scripts/validate-rules.sh].

---

## Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Missing `release: kube-prometheus-stack` label | Prometheus ignores the resource | Add to metadata.labels |
| ServiceMonitor selector does not match any service | No metrics scraped, no error | Verify labels with `kubectl get svc -n <ns> --show-labels` |
| Using `ready: true` in canary Kubernetes checks | False negatives after pod restarts | Use CEL `test.expr` |
| Hardcoding domains in canary URLs | Breaks across clusters | Use `${internal_domain}` |
| Very short `for` on flappy metrics | Alert noise | Use 10m+ for error rates and latencies |
| Creating alerts for non-existent metrics | Alert stuck in "pending" | Verify metrics exist in Prometheus first |

---

## Keywords

PrometheusRule, ServiceMonitor, PodMonitor, ScrapeConfig, AlertmanagerConfig, Silence,
silence-operator, canary-checker, Canary, recording rules, alert rules, monitoring,
observability, scrape targets, prometheus, alertmanager, discord, heartbeat

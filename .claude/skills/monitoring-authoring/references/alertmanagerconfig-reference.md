# AlertmanagerConfig and Silence Reference

## AlertmanagerConfig

The platform Alertmanager configuration lives in `config/monitoring/alertmanager-config.yaml`.

### Current Routing Architecture

```
All alerts
  ├── InfoInhibitor → null receiver (silenced)
  ├── Watchdog → heartbeat receiver (webhook to healthchecks.io, every 2m)
  └── severity=critical → discord receiver
  └── (default) → discord receiver
```

### Receivers

| Receiver | Type | Purpose |
|----------|------|---------|
| `"null"` | None | Silences matched alerts (e.g., InfoInhibitor) |
| `heartbeat` | Webhook | Sends Watchdog heartbeat to healthchecks.io |
| `discord` | Discord webhook | Sends alerts to Discord channel |

### Adding a New Route

```yaml
routes:
  - receiver: "<receiver-name>"
    matchers:
      - name: alertname
        value: "<AlertName>"
        matchType: =
```

### Secrets

| Secret | Source | File |
|--------|--------|------|
| `alertmanager-discord-webhook` | ExternalSecret (AWS SSM) | `discord-secret.yaml` |
| `alertmanager-heartbeat-ping-url` | Replicated from `kube-system` | `heartbeat-secret.yaml` |

---

## Silence CRs (silence-operator)

Silences suppress known alerts declaratively. They are per-cluster resources.

### Template

```yaml
---
# <Comment explaining WHY this alert is silenced>
apiVersion: observability.giantswarm.io/v1alpha2
kind: Silence
metadata:
  name: <descriptive-name>
  namespace: monitoring
spec:
  matchers:
    - name: alertname
      matchType: "=~"           # "=" exact, "=~" regex, "!=" negation, "!~" regex negation
      value: "Alert1|Alert2"
    - name: namespace
      matchType: "="
      value: <target-namespace>
```

### Matcher Reference

| matchType | Meaning | Example |
|-----------|---------|---------|
| `=` | Exact match | `value: "KubePodCrashLooping"` |
| `!=` | Not equal | `value: "Watchdog"` |
| `=~` | Regex match | `value: "KubePod.*\|TargetDown"` |
| `!~` | Regex negation | `value: "Info.*"` |

### Silence Requirements

- Always include a comment explaining WHY the silence exists
- Silences are a LAST RESORT — fix the root cause first; only silence for architectural limitations, expected environmental behavior, or confirmed upstream bugs
- Every cluster maintains a zero firing alerts baseline (excluding Watchdog)
- Never leave alerts firing without action — either fix or silence. An ignored alert leads to alert fatigue

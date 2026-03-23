# Alertmanager Silences Reference

## Silence CRD Structure

```yaml
apiVersion: observability.giantswarm.io/v1alpha2
kind: Silence
metadata:
  name: descriptive-silence-name
  namespace: monitoring
spec:
  matchers:
    - name: alertname
      matchType: "=~"           # "=" for exact, "=~" for regex
      value: "Alert1|Alert2"
    - name: namespace
      matchType: "="
      value: target-namespace
```

## Matcher Reference

| Field | Values | Description |
|-------|--------|-------------|
| `matchType` | `=`, `!=`, `=~`, `!~` | Exact match, negation, regex match, regex negation |
| `name` | Any alert label | Common: `alertname`, `namespace`, `severity`, `job` |
| `value` | String or regex | Multiple alerts: `"Alert1\|Alert2\|Alert3"` |

## Adding a Cluster-Specific Silence

1. Create `config/silences/` directory if it doesn't exist
2. Add the Silence YAML file (see structure above)
3. Add to `config/silences/kustomization.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - my-silence.yaml
   ```
4. Reference `silences` in `config/kustomization.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - silences
   ```

**Zero-alert requirement:** Every cluster must maintain zero firing alerts (excluding Watchdog). When an alert cannot be fixed (e.g., architectural limitation like single-node Spegel), silence it declaratively with a comment explaining why.

### Example: Dev-Only Silence

The dev cluster silences the Spegel peer alert because single-node clusters can't find P2P peers:

```
clusters/dev/
├── config/
│   ├── kustomization.yaml    # resources: [silences]
│   └── silences/
│       ├── kustomization.yaml    # resources: [spegel-single-node.yaml]
│       └── spegel-single-node.yaml
```

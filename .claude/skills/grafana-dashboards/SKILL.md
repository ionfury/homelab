---
name: grafana-dashboards
description: |
  Author Grafana dashboards with MCP-driven metric discovery, visual iteration via
  the image renderer, and consistent layout conventions extracted from existing dashboards.

  Use when: (1) Creating new Grafana dashboards, (2) Modifying existing dashboard JSON,
  (3) Adding panels or sections to dashboards, (4) Choosing metrics and PromQL for panels,
  (5) Debugging blank or broken dashboard panels, (6) Laying out dashboard grids.

  Triggers: "grafana dashboard", "create dashboard", "add panel", "dashboard layout",
  "grafana json", "dashboard ConfigMap", "new dashboard", "visualize metrics"
user-invocable: false
---

# Grafana Dashboard Authoring

This skill covers creating and iterating on Grafana dashboards using the MCP-driven workflow.
For querying Prometheus directly, see the [prometheus skill](../prometheus/SKILL.md).
For monitoring resources (alerts, ServiceMonitors), see the [monitoring-authoring skill](../monitoring-authoring/SKILL.md).

## Prerequisites

- **mcp-grafana MCP server** configured in `.mcp.json` (already set up)
- **Port-forward to Grafana**: `kubectl port-forward svc/grafana 3000:80 -n monitoring &`
- **Image Renderer** deployed in-cluster (enabled in Grafana Helm values)

Anonymous auth is enabled at Admin role — no service account token needed.

---

## MCP-Driven Workflow

discover metrics → build JSON → push to Grafana → screenshot → iterate → write ConfigMap

### Step 1: Discover Available Metrics

**Never guess metric names.** Always discover them via MCP first:

```
MCP tool: list_prometheus_metric_names        # Find what exists
MCP tool: list_prometheus_metric_metadata     # Type and help text  (metric: "up")
MCP tool: list_prometheus_label_values        # Filter options      (label: "namespace")
MCP tool: query_prometheus                    # Test a query        (expr: "sum(...)")
```

### Step 2: Build Dashboard JSON

Use the conventions in this skill plus the reference files below to construct dashboard JSON.

### Step 3: Push to Grafana for Preview

```
MCP tool: update_dashboard
  dashboard: { ...full dashboard JSON... }
  overwrite: true
```

Grafana has `persistence.enabled: false` — dashboards pushed via API are ephemeral (survive until pod restart). Safe to experiment freely.

### Step 4: Visual Review with Screenshots

```
MCP tool: get_panel_image
  dashboardUid: "my-dashboard"
  panelId: 1          # omit for full dashboard
  width: 800
  height: 400
  theme: "dark"
```

### Step 5: Iterate

Repeat steps 2-4 until satisfied.

### Step 6: Write ConfigMap for Git

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-<slug>
  namespace: monitoring
  labels:
    grafana_dashboard: "true"       # REQUIRED for sidecar discovery
  annotations:
    grafana_folder: "<FolderName>"  # Controls Grafana UI folder
data:
  <slug>.json: |-
    { ...dashboard JSON... }
```

Register in `kubernetes/platform/config/monitoring/kustomization.yaml` (add alphabetically).

Data key should match the dashboard `uid`. Use `|-` for the JSON body.

---

## Dashboard Structure

See [references/dashboard-reference.md] for the full JSON skeleton, field conventions, folder taxonomy, and existing dashboard UIDs to use as reference.

Key rules:
- `"id": null` always (Grafana assigns on import)
- `"graphTooltip": 1` always (shared crosshair)
- `"datasource": { "type": "prometheus", "uid": "prometheus" }` always — never `${datasource}`
- `"uid"` — kebab-case, unique across all dashboards

---

## Grid Layout

The Grafana grid is **24 columns wide**. See [references/layout-conventions.md] for width/height tables and layout patterns.

Quick reference:
- Three equal panels: `w:8` each, `x: 0, 8, 16`
- Four stat panels: `w:6` each, `x: 0, 6, 12, 18`
- Six compact stats: `w:4` each, `x: 0, 4, 8, 12, 16, 20`
- Rows: always `h:1, w:24, x:0`; panels start at `y: row_y + 1`

---

## Panel Types

See [references/panel-reference.md] for complete JSON examples for stat, timeseries, gauge, table, and bar gauge panels.

Every panel must have a `"description"` field that:
1. States what the metric measures
2. Names the alert that fires when the threshold is crossed (if applicable)
3. Indicates which direction is bad

Example: `"Active DB connections as % of max_connections. Above 80% triggers CNPGClusterHighConnections."`

---

## PromQL, Colors, and Units

See [references/promql-patterns.md] for:
- Common PromQL patterns (rate, ratio, histogram quantile, boolean, time-based)
- Unit reference table
- Color/threshold conventions (more-is-worse, less-is-worse, binary)
- Domain-specific threshold values (DB, cache, storage, temperature, backup)

---

## Anti-Patterns

| Mistake | Impact | Fix |
|---------|--------|-----|
| Guessing metric names | Blank panels | Use MCP `list_prometheus_metric_names` first |
| Using `${datasource}` variable | Breaks on import | Always `{ "type": "prometheus", "uid": "prometheus" }` |
| Hardcoding domains in panel links | Breaks across clusters | Use `${internal_domain}` substitution |
| Overlapping `gridPos` coordinates | Panels stack incorrectly | Calculate y offsets carefully |
| Missing `grafana_dashboard: "true"` label | Sidecar ignores ConfigMap | Always include the label |
| Including `pluginVersion` field | Churn on Grafana upgrades | Omit from new dashboards |
| Setting `"id"` to a specific number | Conflicts on import | Always use `null` |

---

## Keywords

Grafana, dashboard, JSON, ConfigMap, sidecar, panel, timeseries, stat, gauge, table,
bar gauge, gridPos, layout, PromQL, metrics, visualization, image renderer, screenshot,
mcp-grafana, dashboard authoring

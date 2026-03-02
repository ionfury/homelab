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

---

## Prerequisites

The dashboard development workflow requires:

1. **mcp-grafana MCP server** configured in `.mcp.json` (already set up)
2. **Port-forward to Grafana** on the target cluster (usually live for real metrics)
3. **Image Renderer** deployed in-cluster (enabled in Grafana Helm values)

### Starting a Dashboard Session

```bash
# Port-forward Grafana to localhost:3000 (background)
kubectl port-forward svc/grafana 3000:80 -n monitoring &
```

The `.mcp.json` configures mcp-grafana to connect to `http://localhost:3000`. With anonymous
auth enabled at Admin role, no service account token is needed.

---

## MCP-Driven Workflow

### Step 1: Discover Available Metrics

Before writing any PromQL, use MCP tools to find what metrics actually exist:

```
# List all metric names (find what's available)
MCP tool: list_prometheus_metric_names

# Get metadata for a metric (type, help text)
MCP tool: list_prometheus_metric_metadata
  metric: "up"

# Find label values for filtering
MCP tool: list_prometheus_label_values
  label: "namespace"

# Test a PromQL query
MCP tool: query_prometheus
  expr: "sum(rate(http_requests_total[5m])) by (job)"
```

**Never guess metric names.** Always discover them via MCP first.

### Step 2: Build Dashboard JSON

Use the conventions in this skill to construct the dashboard JSON. Follow the grid system,
color semantics, and panel patterns documented below.

### Step 3: Push to Grafana for Preview

```
# Push dashboard via API (ephemeral — survives until pod restart)
MCP tool: update_dashboard
  dashboard: { ...full dashboard JSON... }
  overwrite: true
```

Since Grafana has `persistence.enabled: false`, dashboards pushed via the API are ephemeral.
The sidecar ConfigMaps from git are the real source of truth. This is a safety feature — you
can freely experiment without affecting production state.

### Step 4: Visual Review with Screenshots

```
# Screenshot a specific panel
MCP tool: get_panel_image
  dashboardUid: "my-dashboard"
  panelId: 1
  width: 800
  height: 400
  theme: "dark"

# Screenshot the full dashboard
MCP tool: get_panel_image
  dashboardUid: "my-dashboard"
  width: 1600
  height: 900
  theme: "dark"
```

Review the image output and iterate on layout, colors, and panel sizing.

### Step 5: Iterate

Repeat steps 2-4 until the dashboard looks right. Then write the final version as a
ConfigMap YAML file for git.

### Step 6: Write ConfigMap for Git

Once satisfied, write the dashboard as a ConfigMap YAML (see template below) and add it
to the appropriate kustomization.

---

## ConfigMap Template

Every custom dashboard is a ConfigMap picked up by the Grafana sidecar:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboard-<slug>
  namespace: monitoring
  labels:
    grafana_dashboard: "true"
  annotations:
    grafana_folder: "<FolderName>"
data:
  <slug>.json: |-
    {
      ...dashboard JSON...
    }
```

**Requirements:**
- Label `grafana_dashboard: "true"` is mandatory for sidecar discovery
- Annotation `grafana_folder` controls the Grafana UI folder
- Data key name should match the dashboard `uid` (e.g., `my-dashboard.json`)
- Use `|-` (literal block, strip trailing newline) for the JSON body

### Registration

Add the new file to the monitoring kustomization:

```yaml
# kubernetes/platform/config/monitoring/kustomization.yaml
resources:
  - ...existing resources...
  - <slug>-dashboard.yaml    # Add alphabetically
```

---

## Dashboard JSON Skeleton

Every dashboard JSON uses this structure:

```json
{
  "annotations": { "list": [] },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 1,
  "id": null,
  "links": [],
  "panels": [],
  "schemaVersion": 39,
  "tags": [],
  "templating": { "list": [] },
  "time": { "from": "now-3h", "to": "now" },
  "timepicker": {},
  "timezone": "",
  "title": "Dashboard Title",
  "uid": "dashboard-uid",
  "version": 1
}
```

**Field conventions:**
- `"id": null` — always null; Grafana assigns on import
- `"graphTooltip": 1` — shared crosshair across all panels (always use this)
- `"schemaVersion": 39` — current schema version
- `"timezone": ""` — empty string for UTC-relative (preferred for ops dashboards)
- `"uid"` — kebab-case, must be unique across all dashboards
- `"title"` — Title Case
- `"time.from"` — set by use case: `now-3h` (operational), `now-6h` (service), `now-24h` (daily), `now-7d` (trend)

---

## Grid Layout System

The Grafana grid is **24 columns wide**. All positioning uses `gridPos`.

### Standard Panel Widths

| Columns (w) | Layout | Typical Use |
|-------------|--------|-------------|
| 24 | Full width | Wide timeseries, full-width tables |
| 12 | Half | Side-by-side panels |
| 8 | Third | Three equal panels per row (most common) |
| 6 | Quarter | Four stat panels across a row |
| 4 | Sixth | Six compact stat panels |

### Standard Panel Heights

| Height (h) | Typical Use |
|------------|-------------|
| 1 | Row separator |
| 4 | Small stat panels |
| 5 | Medium stat panels |
| 6 | Stat panels with sparkline |
| 8 | Standard timeseries/gauge panels |
| 10 | Tall timeseries or tables |

### Row Panel Pattern

Rows are section headers that group panels:

```json
{
  "collapsed": false,
  "gridPos": { "h": 1, "w": 24, "x": 0, "y": 0 },
  "id": 10,
  "title": "Section Name",
  "type": "row"
}
```

### Layout Rules

- Rows always at `x: 0, w: 24, h: 1`
- After a row, panels start at `y: row_y + 1`
- Panels on the same horizontal line share the same `y`
- Increment `y` by panel `h` to get the next row's starting `y`
- Section IDs are multiples of 10 (10, 20, 30...) for easy insertion
- Panel IDs within a section are sequential from the section base

### Common Layout Patterns

**Three equal panels (most common):**
```
Row:   { h:1,  w:24, x:0,  y:0  }
Left:  { h:8,  w:8,  x:0,  y:1  }
Mid:   { h:8,  w:8,  x:8,  y:1  }
Right: { h:8,  w:8,  x:16, y:1  }
Next:  y=9
```

**Four stat panels:**
```
Row:   { h:1,  w:24, x:0,  y:0  }
S1:    { h:4,  w:6,  x:0,  y:1  }
S2:    { h:4,  w:6,  x:6,  y:1  }
S3:    { h:4,  w:6,  x:12, y:1  }
S4:    { h:4,  w:6,  x:18, y:1  }
Next:  y=5
```

**Six compact stat panels:**
```
S1-S6: { h:4, w:4, x:0/4/8/12/16/20, y:1 }
```

**Stats row + timeseries below:**
```
Row:    { h:1,  w:24, x:0,  y:0  }
S1-S4:  { h:4,  w:6,  x:0/6/12/18, y:1  }
Chart1: { h:8,  w:12, x:0,  y:5  }
Chart2: { h:8,  w:12, x:12, y:5  }
Next:   y=13
```

---

## Panel Types and Patterns

### Stat Panel

For single values, KPIs, and status indicators:

```json
{
  "type": "stat",
  "title": "Panel Title",
  "description": "What this metric measures and which alert fires when threshold is crossed.",
  "gridPos": { "h": 4, "w": 6, "x": 0, "y": 1 },
  "id": 11,
  "datasource": { "type": "prometheus", "uid": "prometheus" },
  "targets": [
    {
      "expr": "your_promql_here",
      "legendFormat": "",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "color": { "mode": "thresholds" },
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "yellow", "value": 70 },
          { "color": "red", "value": 90 }
        ]
      },
      "unit": "percent"
    },
    "overrides": []
  },
  "options": {
    "colorMode": "background",
    "graphMode": "none",
    "justifyMode": "auto",
    "orientation": "auto",
    "reduceOptions": {
      "calcs": ["lastNotNull"],
      "fields": "",
      "values": false
    },
    "textMode": "auto"
  }
}
```

**Stat options:**
- `"colorMode": "background"` — fills panel background (preferred for status)
- `"graphMode": "area"` — adds sparkline behind value
- `"graphMode": "none"` — value only

### Timeseries Panel

For metrics over time:

```json
{
  "type": "timeseries",
  "title": "Panel Title",
  "description": "What this metric shows and why it matters.",
  "gridPos": { "h": 8, "w": 8, "x": 0, "y": 1 },
  "id": 12,
  "datasource": { "type": "prometheus", "uid": "prometheus" },
  "targets": [
    {
      "expr": "sum(rate(metric_total[5m])) by (label)",
      "legendFormat": "{{ label }}",
      "refId": "A"
    }
  ],
  "fieldConfig": {
    "defaults": {
      "color": { "mode": "palette-classic" },
      "custom": {
        "axisBorderShow": false,
        "axisLabel": "",
        "drawStyle": "line",
        "fillOpacity": 10,
        "gradientMode": "scheme",
        "lineWidth": 2,
        "pointSize": 5,
        "showPoints": "never",
        "stacking": { "group": "A", "mode": "none" },
        "thresholdsStyle": { "mode": "off" }
      },
      "unit": "reqps"
    },
    "overrides": []
  },
  "options": {
    "legend": {
      "calcs": ["mean", "lastNotNull"],
      "displayMode": "table",
      "placement": "bottom"
    },
    "tooltip": { "mode": "multi", "sort": "desc" }
  }
}
```

**Timeseries customization:**
- `"fillOpacity"`: 10 (subtle), 20 (visible), 40 (stacked area)
- `"lineInterpolation"`: `"smooth"` for hardware, omit for default linear
- `"stacking.mode"`: `"none"` (default) or `"normal"` for stacked area
- `"thresholdsStyle.mode"`: `"off"` (default) or `"dashed"` for threshold lines

**Legend calcs by context:**
- `["mean", "lastNotNull"]` — rates, active metrics (most common)
- `["mean", "max"]` — peak tracking (latency, replication lag)
- `["mean", "min", "max"]` — full range (power, temperature)
- `["sum"]` — totals (energy, data transferred)

### Gauge Panel

For percentage/utilization with threshold markers:

```json
{
  "type": "gauge",
  "fieldConfig": {
    "defaults": {
      "color": { "mode": "thresholds" },
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "yellow", "value": 70 },
          { "color": "red", "value": 90 }
        ]
      },
      "unit": "percent",
      "min": 0,
      "max": 100
    }
  },
  "options": {
    "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false },
    "showThresholdLabels": false,
    "showThresholdMarkers": true,
    "orientation": "auto"
  }
}
```

### Table Panel

For multi-series instant queries and per-resource data:

```json
{
  "type": "table",
  "targets": [
    {
      "expr": "your_instant_query",
      "format": "table",
      "instant": true,
      "legendFormat": "",
      "refId": "A"
    }
  ],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": { "Time": true, "__name__": true, "job": true },
        "renameByName": { "Value": "Used %", "persistentvolumeclaim": "PVC" }
      }
    },
    {
      "id": "sortBy",
      "options": { "sort": [{ "field": "Used %", "desc": true }] }
    }
  ],
  "options": {
    "showHeader": true,
    "cellHeight": "sm",
    "footer": { "enablePagination": false, "show": false }
  }
}
```

**Table cell styling (via fieldConfig overrides):**
```json
{
  "matcher": { "id": "byName", "options": "Used %" },
  "properties": [
    { "id": "custom.cellOptions", "value": { "mode": "gradient", "type": "gauge" } },
    { "id": "min", "value": 0 },
    { "id": "max", "value": 100 }
  ]
}
```

### Bar Gauge Panel

For comparative bars (e.g., disk wear across devices):

```json
{
  "type": "bargauge",
  "options": {
    "displayMode": "gradient",
    "orientation": "horizontal",
    "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false }
  }
}
```

---

## Color and Threshold Conventions

### Threshold Direction

All thresholds use `"mode": "absolute"`.

**"More is worse" (utilization, errors, lag):**
```json
"steps": [
  { "color": "green",  "value": null },
  { "color": "yellow", "value": 70 },
  { "color": "orange", "value": 85 },
  { "color": "red",    "value": 95 }
]
```

**"Less is worse" (availability, cache hit ratio):**
```json
"steps": [
  { "color": "red",    "value": null },
  { "color": "yellow", "value": 50 },
  { "color": "green",  "value": 90 }
]
```

**Binary status (healthy/unhealthy):**
```json
"steps": [
  { "color": "red",   "value": null },
  { "color": "green", "value": 1 }
]
```

### Domain-Specific Thresholds

| Signal | Yellow | Orange | Red |
|--------|--------|--------|-----|
| DB connections % | 60 | 80 | 90 |
| Cache memory % | 70 | 90 | 95 |
| Storage/PVC % | 70 | 85 | 95 |
| CPU/GPU temp (C) | — | 75 | 85 |
| Disk temp (C) | — | 45 | 55 |
| Backup age (s) | 86400 | — | 172800 |
| WAL backlog | 10 | — | 100 |

### Color Modes

| color.mode | When to Use |
|------------|-------------|
| `palette-classic` | Timeseries with multiple series |
| `thresholds` | Stat, gauge, table cells with threshold coloring |
| `fixed` | Overrides for specific series (e.g., dashed reference line) |

---

## Value Mappings

Map numeric values to human-readable labels:

```json
"mappings": [
  {
    "type": "value",
    "options": {
      "0": { "text": "FAILING", "color": "red" },
      "1": { "text": "OK",      "color": "green" }
    }
  }
]
```

Use `"noValue": "N/A"` in fieldConfig.defaults when a metric may legitimately be absent.

---

## Datasource Reference

**Always** use the hardcoded datasource reference:

```json
"datasource": { "type": "prometheus", "uid": "prometheus" }
```

Never use datasource variables (`${datasource}`). The uid `"prometheus"` is the provisioned
datasource UID from the Grafana Helm values.

---

## Unit Reference

| Unit | Meaning |
|------|---------|
| `reqps` | Requests per second |
| `s` | Seconds |
| `ms` | Milliseconds |
| `percent` | 0-100 percentage |
| `percentunit` | 0.0-1.0 fraction |
| `bytes` | Bytes |
| `Bps` | Bytes per second |
| `watt` | Watts |
| `kwatth` | Kilowatt-hours |
| `currencyUSD` | US dollars |
| `celsius` | Temperature |
| `rotrpm` | Rotations per minute |
| `volt` | Volts |
| `ops` | Operations per second |
| `cps` | Counts per second |
| `h` | Hours |
| `short` | Unitless count |

---

## Common PromQL Patterns

### Rate and Ratio
```promql
rate(metric_total[5m])
sum(rate(metric_total{label=~"filter.*"}[5m]))
100 * sum(rate(metric{code!~"5.*"}[5m])) / sum(rate(metric[5m]))
```

### Histogram Quantiles
```promql
histogram_quantile(0.99, sum(rate(metric_bucket[5m])) by (le))
```

### Boolean / Presence Counting
```promql
count(resource_info{ready="False"})
count(metric != 1) or vector(0)
100 * count(resource_info{ready="True"}) / count(resource_info)
```

### Time-Based (Backup Age)
```promql
time() - metric_timestamp
```

### Per-Resource Breakdowns
```promql
sum by (instance) (rate(metric[5m]))
sum(rate(metric[5m])) by (api_endpoint)
```

---

## Panel Description Convention

Every panel must have a `"description"` field that:
1. States what the metric measures (one sentence)
2. Names the alert that fires when threshold is crossed (if applicable)
3. Indicates which direction is bad

Example:
> "Active database connections as a percentage of max_connections. Above 80% triggers CNPGClusterHighConnections alert."

---

## Dashboard Folder Taxonomy

Assign dashboards to existing folders via the `grafana_folder` annotation:

| Folder | Scope |
|--------|-------|
| Kubernetes | K8s cluster views (nodes, pods, namespaces) |
| Infrastructure | Node exporter, Prometheus, Flux |
| Network | Istio, Cilium, Cloudflared, UniFi |
| Storage | Longhorn, volumes, Garage S3 |
| Hardware | SMART, IPMI, GPU, temperatures |
| Applications | User-facing applications |
| Platform Services | cert-manager, external-dns, external-secrets |
| Database | CNPG, Dragonfly |
| Power | UPS, power accounting |
| SRE | Capacity planning, golden signals, platform signals |
| Backup | Backup health and verification |

---

## Existing Dashboard Reference

Learn from these existing custom dashboards:

| Dashboard | UID | Folder | Key Patterns |
|-----------|-----|--------|-------------|
| Platform Signals | `platform-signals` | SRE | Golden signals, related dashboard links, multi-section layout |
| Hardware Health | `hardware-health` | Hardware | Table with inline gauges, SMART matrix, temperature sparklines |
| Power Accounting | `power-accounting` | Hardware | Cost projection with variables, stacked area, dashed reference lines |
| Garage S3 Storage | `garage-s3-storage` | Storage | Six-stat health row, rate panels, replication monitoring |
| Backup Health | `backup-health` | Backup | Time-based thresholds, `vector(0)` fallback, `noValue` for absent metrics |

Use MCP `get_dashboard_by_uid` to pull and inspect any of these as reference.

---

## Anti-Patterns

| Mistake | Impact | Fix |
|---------|--------|-----|
| Guessing metric names | Blank panels | Use MCP `list_prometheus_metric_names` first |
| Using `${datasource}` variable | Breaks on import | Always use `{ "type": "prometheus", "uid": "prometheus" }` |
| Hardcoding domains in panel links | Breaks across clusters | Use `${internal_domain}` substitution |
| Overlapping `gridPos` coordinates | Panels stack incorrectly | Calculate y offsets carefully |
| Missing `grafana_dashboard: "true"` label | Sidecar ignores ConfigMap | Always include the label |
| Including `pluginVersion` field | Churn on Grafana upgrades | Omit from new dashboards |
| Setting `"id"` to a specific number | Conflicts on import | Always use `null` for top-level `"id"` |

---

## Keywords

Grafana, dashboard, JSON, ConfigMap, sidecar, panel, timeseries, stat, gauge, table,
bar gauge, gridPos, layout, PromQL, metrics, visualization, image renderer, screenshot,
mcp-grafana, dashboard authoring

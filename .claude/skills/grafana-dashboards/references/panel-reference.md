# Panel Types Reference

All panels share these common fields:
- `"datasource": { "type": "prometheus", "uid": "prometheus" }` — always hardcoded, never use `${datasource}`
- `"description"` — required; state what the metric measures, which alert fires, and which direction is bad

---

## Stat Panel

For single values, KPIs, and status indicators.

```json
{
  "type": "stat",
  "title": "Panel Title",
  "description": "What this metric measures and which alert fires when threshold is crossed.",
  "gridPos": { "h": 4, "w": 6, "x": 0, "y": 1 },
  "id": 11,
  "datasource": { "type": "prometheus", "uid": "prometheus" },
  "targets": [
    { "expr": "your_promql_here", "legendFormat": "", "refId": "A" }
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
    "reduceOptions": { "calcs": ["lastNotNull"], "fields": "", "values": false },
    "textMode": "auto"
  }
}
```

**Options:**
- `"colorMode": "background"` — fills panel background (preferred for status)
- `"graphMode": "area"` — adds sparkline behind value; `"none"` — value only

---

## Timeseries Panel

For metrics over time.

```json
{
  "type": "timeseries",
  "title": "Panel Title",
  "description": "What this metric shows and why it matters.",
  "gridPos": { "h": 8, "w": 8, "x": 0, "y": 1 },
  "id": 12,
  "datasource": { "type": "prometheus", "uid": "prometheus" },
  "targets": [
    { "expr": "sum(rate(metric_total[5m])) by (label)", "legendFormat": "{{ label }}", "refId": "A" }
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
    "legend": { "calcs": ["mean", "lastNotNull"], "displayMode": "table", "placement": "bottom" },
    "tooltip": { "mode": "multi", "sort": "desc" }
  }
}
```

**Customization:**
- `"fillOpacity"`: 10 (subtle), 20 (visible), 40 (stacked area)
- `"lineInterpolation"`: `"smooth"` for hardware, omit for default linear
- `"stacking.mode"`: `"none"` (default) or `"normal"` for stacked area
- `"thresholdsStyle.mode"`: `"off"` (default) or `"dashed"` for threshold lines

**Legend calcs by context:**
- `["mean", "lastNotNull"]` — rates, active metrics (most common)
- `["mean", "max"]` — peak tracking (latency, replication lag)
- `["mean", "min", "max"]` — full range (power, temperature)
- `["sum"]` — totals (energy, data transferred)

---

## Gauge Panel

For percentage/utilization with threshold markers.

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

---

## Table Panel

For multi-series instant queries and per-resource data.

```json
{
  "type": "table",
  "targets": [
    { "expr": "your_instant_query", "format": "table", "instant": true, "legendFormat": "", "refId": "A" }
  ],
  "transformations": [
    {
      "id": "organize",
      "options": {
        "excludeByName": { "Time": true, "__name__": true, "job": true },
        "renameByName": { "Value": "Used %", "persistentvolumeclaim": "PVC" }
      }
    },
    { "id": "sortBy", "options": { "sort": [{ "field": "Used %", "desc": true }] } }
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

---

## Bar Gauge Panel

For comparative bars (e.g., disk wear across devices).

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

Use `"noValue": "N/A"` in `fieldConfig.defaults` when a metric may legitimately be absent.

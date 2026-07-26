---
name: dashboard-design
description: |
  Visual design and layout for Grafana dashboards — panel hierarchy, type selection,
  color/threshold design, and iterative screenshot-based refinement.

  Use when: (1) Deciding what panels belong on a new dashboard, (2) Choosing panel
  types for specific data patterns, (3) Structuring visual hierarchy and layout,
  (4) Applying color and thresholds to communicate status, (5) Reviewing dashboard
  appearance via Playwright screenshots, (6) Iterating on readability and density

  Triggers: "dashboard design", "visual design", "layout design", "panel type",
  "color scheme", "screenshot review", "iterate dashboard", "dashboard looks",
  "visual feedback", "refine dashboard", "dashboard hierarchy", "information density"
user-invocable: false
---

# Dashboard Design

Design judgment for Grafana dashboards — what to build and how it should look.
For authoring mechanics (MCP workflow, JSON templates, ConfigMap), see the
[grafana-dashboards skill](../grafana-dashboards/SKILL.md).
For alert and ServiceMonitor authoring, see [monitoring-authoring](../monitoring-authoring/SKILL.md).

---

## Design Workflow

```
Define purpose → Layout hierarchy → Select panel types → Apply color/thresholds
     → Push via MCP → Screenshot review → Iterate → Hand off to grafana-dashboards
```

---

## Step 1: Define Dashboard Purpose

One dashboard = one question it answers. Examples:
- "Is the platform healthy right now?" → Platform Home
- "Why is latency elevated?" → Service-level signals
- "How full is storage?" → Storage capacity

If you can't state the question in one sentence, split into multiple dashboards.

---

## Step 2: Layout Hierarchy

Structure rows top-to-bottom by audience urgency (Z-pattern reading flow):

| Row Position | Content | Panel Type |
|-------------|---------|------------|
| **Hero** (top) | Availability, error rate, SLO status | Stat (w:6, 3-4 panels) |
| **Supporting** | Latency/throughput trends, saturation | Timeseries (w:12 or w:24) |
| **Detail** | Per-resource breakdown, logs correlation | Table, Bar Gauge |
| **Debug** (bottom) | Raw counters, cardinality, internal stats | Collapsed rows |

**Grid widths** (24-column grid):
- 4 stats per row: `w:6` at `x: 0, 6, 12, 18`
- 3 panels per row: `w:8` at `x: 0, 8, 16`
- 6 compact stats: `w:4` at `x: 0, 4, 8, 12, 16, 20`
- Full-width: `w:24`

---

## Step 3: Panel Type Selection

| Data Pattern | Use | Why |
|-------------|-----|-----|
| Single current value | **Stat** | Instant read + threshold color |
| Trend over time | **Timeseries** | Shows rate/pattern changes |
| % of bounded range | **Gauge** | Circular fill = intuitive utilization |
| Multiple resources | **Table** | Scannable multi-row comparison |
| Categorical compare | **Bar Gauge** | Side-by-side without time axis |
| Binary state (0/1) | **Stat + value mapping** | Maps 0→"DOWN"/red, 1→"UP"/green |

**Stat panels** dominate this codebase (54 stat : 42 timeseries : 18 gauge). Default to
stat for KPIs, timeseries for anything with meaningful time shape.

---

## Step 4: Color & Threshold Design

Two threshold modes — pick based on which direction is bad:

**More-is-worse** (errors, utilization, latency):
```json
"steps": [
  { "color": "green", "value": null },
  { "color": "yellow", "value": 70 },
  { "color": "red", "value": 90 }
]
```

**Less-is-worse** (availability %, SLO compliance):
```json
"steps": [
  { "color": "red", "value": null },
  { "color": "yellow", "value": 50 },
  { "color": "green", "value": 90 }
]
```

Binary (on/off, present/absent):
```json
"mappings": [{ "type": "value", "options": {
  "0": { "text": "DOWN", "color": "red" },
  "1": { "text": "UP", "color": "green" }
}}]
```

Domain thresholds from this codebase:

| Signal | Yellow | Red |
|--------|--------|-----|
| DB connections % | 60 | 80 |
| Storage/PVC % | 70 | 95 |
| CPU/GPU temp (°C) | 75 | 85 |
| Backup age (s) | 86400 | 172800 |

---

## Step 5: Visual Review Loop

Use MCP `get_panel_image` for quick panel review during authoring:
```
MCP: get_panel_image  dashboardUid: "uid"  panelId: 1  width: 800  height: 400
```

Use **Playwright** for full-dashboard layout review (spacing, row flow, color consistency):
```
1. kubectl port-forward svc/grafana 3000:80 -n monitoring
2. Navigate to http://localhost:3000/d/<uid>
3. browser_take_screenshot → inspect layout, color, readability
4. Fix issues, push via MCP update_dashboard, re-screenshot
```

Check for: crowded rows, inconsistent threshold colors, missing panel titles,
axes without units, buried golden signals.

---

## Anti-Patterns

| Mistake | Impact | Fix |
|---------|--------|-----|
| Golden signals buried below fold | Missed during incidents | Move availability/error rate to hero row |
| All panels same size/weight | No hierarchy, eye wanders | Hero stats larger; detail rows compact |
| >6 panels per row | Unreadable on standard displays | Max 4 normal stats, 6 compact |
| Missing threshold steps | No visual status signal | Every stat and gauge needs thresholds |
| Decorative panels (icons, banners) | Noise, no decision value | Remove anything that doesn't drive action |
| One dashboard for everything | Cognitive overload | Split by audience/question |
| Static thresholds for traffic-sensitive metrics | Alert fatigue | Note context in panel description |

---

## Keywords

visual design, dashboard layout, panel hierarchy, information architecture, panel type
selection, color semantics, thresholds, Z-pattern, golden signals, SLO, screenshot review,
iterative design, Playwright, visual feedback, information density, stat panel, timeseries,
gauge, table, bar gauge, value mapping, color conventions, grid layout

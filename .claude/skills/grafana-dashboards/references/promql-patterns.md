# PromQL Patterns and Units Reference

## Common PromQL Patterns

**Rate and ratio:**
```promql
rate(metric_total[5m])
sum(rate(metric_total{label=~"filter.*"}[5m]))
100 * sum(rate(metric{code!~"5.*"}[5m])) / sum(rate(metric[5m]))
```

**Histogram quantiles:**
```promql
histogram_quantile(0.99, sum(rate(metric_bucket[5m])) by (le))
```

**Boolean / presence counting:**
```promql
count(resource_info{ready="False"})
count(metric != 1) or vector(0)
100 * count(resource_info{ready="True"}) / count(resource_info)
```

**Time-based (backup age):**
```promql
time() - metric_timestamp
```

**Per-resource breakdowns:**
```promql
sum by (instance) (rate(metric[5m]))
sum(rate(metric[5m])) by (api_endpoint)
```

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

## Color and Threshold Conventions

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

### Color Modes

| color.mode | When to Use |
|------------|-------------|
| `palette-classic` | Timeseries with multiple series |
| `thresholds` | Stat, gauge, table cells with threshold coloring |
| `fixed` | Overrides for specific series (e.g., dashed reference line) |

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

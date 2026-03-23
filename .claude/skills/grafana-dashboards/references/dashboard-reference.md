# Dashboard Structure Reference

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
- `"time.from"` — `now-3h` (operational), `now-6h` (service), `now-24h` (daily), `now-7d` (trend)

## Folder Taxonomy

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

## Existing Custom Dashboards

Learn from these by using MCP `get_dashboard_by_uid`:

| Dashboard | UID | Folder | Key Patterns |
|-----------|-----|--------|-------------|
| Platform Signals | `platform-signals` | SRE | Golden signals, related dashboard links, multi-section layout |
| Hardware Health | `hardware-health` | Hardware | Table with inline gauges, SMART matrix, temperature sparklines |
| Power Accounting | `power-accounting` | Hardware | Cost projection with variables, stacked area, dashed reference lines |
| Garage S3 Storage | `garage-s3-storage` | Storage | Six-stat health row, rate panels, replication monitoring |
| Backup Health | `backup-health` | Backup | Time-based thresholds, `vector(0)` fallback, `noValue` for absent metrics |

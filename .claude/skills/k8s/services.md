# Internal Service URLs

Platform services are exposed through the internal ingress gateway over HTTPS. DNS URLs are for **browser-based access** only.

**OAuth2 Proxy caveat:** Prometheus, Alertmanager, and some other services are behind OAuth2 Proxy. DNS URLs redirect to an OAuth login page and **cannot be used for API queries via curl**. Use `kubectl exec` or port-forward for programmatic access.

| Service | Live URL | Auth | API Access |
|---------|----------|------|------------|
| Prometheus | `https://prometheus.internal.tomnowak.work` | OAuth2 Proxy | `kubectl exec` or port-forward |
| Alertmanager | `https://alertmanager.internal.tomnowak.work` | OAuth2 Proxy | `kubectl exec` or port-forward |
| Grafana | `https://grafana.internal.tomnowak.work` | Built-in auth | Browser only |
| Hubble UI | `https://hubble.internal.tomnowak.work` | None | Browser |
| Longhorn UI | `https://longhorn.internal.tomnowak.work` | None | Browser |
| Garage Admin | `https://garage.internal.tomnowak.work` | None | Browser |

**Domain pattern:** `<service>.internal.<cluster-suffix>.tomnowak.work`
- live: `internal.tomnowak.work`
- integration: `internal.integration.tomnowak.work`
- dev: `internal.dev.tomnowak.work`

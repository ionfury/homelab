# Gateway Routing Reference

## Gateway Selection

| Gateway | Domain | TLS | WAF | IP |
|---------|--------|-----|-----|----|
| `internal` | `*.${internal_domain}` | `homelab-ca` (self-signed CA) | None | `${internal_ingress_ip}` (Cilium LB) |
| `external` | `*.${external_domain}` | `letsencrypt-production` (Cloudflare DNS-01) | Coraza OWASP CRS | `${external_ingress_ip}` (Cilium LB) |

Rule of thumb: platform dashboards (Grafana, Prometheus, Alertmanager, Longhorn, Hubble, Garage) are internal-only. User-facing apps (Authelia, Immich, Zipline) need external and often also an internal route for LAN users.

## ClusterIssuers

| Issuer Name | Type | Use Case | Secret Source |
|------------|------|----------|---------------|
| `cloudflare` | ACME (DNS-01) | Public certs via Let's Encrypt | ExternalSecret from SSM (`cloudflare-api-token`) |
| `homelab-ca` | CA | Internal services, dev/integration clusters | ExternalSecret from SSM (`homelab-ingress-root-ca`) |
| `istio-mesh-ca` | CA | Istio mesh mTLS (workload identity) | ExternalSecret from SSM (shared across clusters) |

## TLS Certificate Architecture

Certificates are provisioned at the gateway level (not per-route). Wildcard certs cover all subdomains — no cert changes needed when adding a new route.

| Gateway | Certificate | Secret | Issuer |
|---------|------------|--------|--------|
| `external` | `external` | `external-tls` | `${tls_issuer:-cloudflare}` |
| `internal` | `internal` | `internal-tls` | `${tls_issuer:-cloudflare}` |

The `tls_issuer` variable defaults to `cloudflare` but can be overridden to `homelab-ca` per cluster via `.cluster-vars.env`.

## TLS Debug Commands

See [`scripts/validate-tls.sh`](../scripts/validate-tls.sh) for the full validation sequence.

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Certificate not Ready | Issuer secret missing | Check ExternalSecret sync for `cloudflare-api-token` |
| ACME challenge failing | DNS propagation / API token issue | Verify Cloudflare token has Zone:DNS:Edit permission |
| `homelab-ca` not Ready | Root CA secret missing | Check ExternalSecret for `homelab-ingress-root-ca` |
| Browser TLS warning (internal) | Self-signed CA not trusted | Expected for `homelab-ca`; add CA to trusted store or use `-k` flag |

## HTTPRoute Field Reference

### parentRefs

```yaml
parentRefs:
  - name: internal          # "internal" or "external"
    namespace: istio-gateway # Always required — gateways live here
    sectionName: https       # Optional; omit to match any listener. Use "http" only for redirect routes.
```

Both gateways use `allowedRoutes.namespaces.from: All` on the HTTPS listener — any namespace can attach.

### Network Policy Profile by Gateway

| Gateway Used | Required Profile |
|-------------|-----------------|
| Internal only | `internal` or `internal-egress` |
| External only | `standard` |
| Both | `standard` |

## WAF Metrics and Alerts

| Metric | What It Shows |
|--------|--------------|
| `istio_requests_total{source_workload=~"external-istio", response_code="403"}` | WAF-blocked requests |
| `istio_requests_total{source_workload=~"external-istio"}` | Total external gateway traffic |

| Alert | Condition | Meaning |
|-------|-----------|---------|
| `CorazaWAFDegraded` | No Istio metrics from external gateway for 5m | Gateway may not be processing traffic |
| `CorazaWAFHighBlockRate` | >10% of requests returning 403 for 10m | Possible attack or WAF false positives |
| `CorazaWAFHighLatency` | p99 gateway latency >50ms for 5m | WAF overhead too high, tune rule exclusions |

## parentRefs Details

`namespace: istio-gateway` is always required (routes are in app namespaces; gateways are in `istio-gateway`). `sectionName` is optional — omit to match any listener; use `http` only for redirect routes. Both gateways allow routes from any namespace.

## Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Route not working | Missing `namespace: istio-gateway` in `parentRefs` | Add namespace to parentRefs |
| 404 on valid hostname | HTTPRoute not attached to gateway | Check `parentRefs` gateway name matches exactly |
| Connection reset on external | SNI mismatch (testing with IP) | Use `--resolve` flag with proper hostname |
| Pods unreachable from gateway | Missing network policy profile | Add `network-policy.homelab/profile` label to namespace |
| 503 Service Unavailable | Backend service not found or port wrong | Verify service name and port in `backendRefs` |
| Both internal and external needed | Only one route created | Create two separate HTTPRoute resources |
| WAF blocking legitimate traffic | False positive on CRS rule | Add `SecRuleRemoveById <ID>` to WasmPlugin directives |

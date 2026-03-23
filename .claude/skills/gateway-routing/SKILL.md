---
name: gateway-routing
description: |
  Gateway API routing, TLS certificates, and WAF configuration for the homelab Kubernetes platform.

  Use when: (1) Exposing a service via HTTPRoute, (2) Choosing between internal and external gateways,
  (3) Debugging TLS or routing issues, (4) Understanding or tuning WAF (Coraza) behavior.

  Triggers: "httproute", "gateway", "expose service", "add route", "certificate", "tls",
  "coraza", "waf", "internal gateway", "external gateway", "dns", "ingress",
  "routing", "cert-manager", "letsencrypt", "homelab-ca"
user-invocable: false
---

# Gateway Routing

The homelab uses Kubernetes Gateway API with Istio as the gateway controller. Two gateways handle traffic:
- **internal** — accessible only within the home network
- **external** — accessible from the internet, protected by Coraza WAF

All gateway resources live in the `istio-gateway` namespace. HTTPRoutes in any namespace reference them via `parentRefs`.

See [references/reference.md](references/reference.md) for gateway selection table, ClusterIssuer comparison, and WAF metrics.

## Gateway Selection

Internal for public internet access -> `external` gateway; internal-only -> `internal` gateway; both -> create two HTTPRoutes (examples: Authelia, Immich, Kromgo).

## Creating an HTTPRoute

Choose gateway and hostname -> create YAML -> place in correct directory -> set network policy profile.

Internal-only route (most common for platform services):

```yaml
---
# yaml-language-server: $schema=https://kubernetes-schemas.pages.dev/gateway.networking.k8s.io/httproute_v1.json
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
spec:
  parentRefs:
    - name: internal
      namespace: istio-gateway
  hostnames:
    - "my-app.${internal_domain}"
  rules:
    - backendRefs:
        - name: my-app-service
          port: 8080
```

External route (internet-facing, WAF-protected) — same structure with `name: external` and `${external_domain}` hostname.

**File placement:** platform services go in `kubernetes/platform/config/<subsystem>/`; cluster-specific apps go in `kubernetes/clusters/<cluster>/config/<app>/`. Add to the subsystem's `kustomization.yaml`.

**Network policy:** set `network-policy.homelab/profile` on the namespace in `kubernetes/platform/namespaces.yaml`. See [references/reference.md](references/reference.md) for profile-by-gateway mapping.

### parentRefs Details

See [references/reference.md](references/reference.md#parentrefs-details).

### Route Patterns

**Simple backend** (most common — Grafana, Longhorn, Hubble, Alertmanager, Prometheus, Garage, Kromgo):
```yaml
rules:
  - backendRefs:
      - name: service-name
        port: 80
```

**Dual gateway:** create two separate HTTPRoute resources, one per gateway, differing only in `parentRefs.name` and `hostnames` domain.

**HTTP-to-HTTPS redirect:** already platform-managed in `config/gateway/http-to-https-redirect.yaml` — do not create redirect routes for new services.

## TLS Certificates

Wildcard certs are provisioned at the gateway level. Adding a new subdomain requires only creating the HTTPRoute — no cert changes needed.

Run `scripts/validate-tls.sh [external|internal]` to check certificate and issuer status.

## Coraza WAF (External Gateway Only)

The WAF runs as an Istio WasmPlugin on the external gateway with OWASP CRS at Paranoia Level 1. Key behaviors:
- **FAIL_OPEN**: if the WASM binary fails to load, traffic flows unfiltered (check gateway pod logs for `applying allow RBAC filter`)
- Rules are inlined in `coraza-wasm-plugin.yaml` (WasmPlugin does not support volume mounts)
- To disable a rule causing false positives: add `- SecRuleRemoveById <ID>` to the `directives_map.default` array

**Testing WAF endpoints** — Istio matches on SNI, so raw IP requests are rejected. Use `--resolve`:

```bash
GATEWAY_IP=$(KUBECONFIG=~/.kube/<cluster>.yaml kubectl get gateway external -n istio-gateway -o jsonpath='{.metadata.annotations.lbipam\.cilium\.io/ips}')
curl -kI --resolve "app.${external_domain}:443:${GATEWAY_IP}" "https://app.${external_domain}/"
```

Attack pattern verification (expect 403): pass `?id=1'%20OR%20'1'='1` (SQLi), `?q=<script>alert(1)</script>` (XSS), or `?cmd=;cat%20/etc/passwd` (RCE) with the same `--resolve` pattern.

## Common Issues

See [references/reference.md](references/reference.md#common-issues).

## Cross-References

| Document | Focus |
|----------|-------|
| `kubernetes/platform/config/gateway/` | Gateway definitions, WAF config |
| `kubernetes/platform/config/issuers/` | ClusterIssuer definitions |
| `kubernetes/platform/config/certs/` | Certificate resources |
| [references/reference.md](references/reference.md) | Gateway table, issuer comparison, WAF metrics |
| `deploy-app` skill | Full app deployment workflow including routing |

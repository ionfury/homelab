# Coraza WAF Implementation Plan

## Overview

This document defines the architectural approach for deploying Coraza WAF as a lightweight HTTP hygiene layer on the external ingress gateway. The design prioritizes simplicity and fail-open behavior over comprehensive security—Coraza filters exploit noise and basic HTTP violations, not sophisticated attacks.

### Goals

- **Exploit noise reduction**: Block common scanner patterns and malformed requests
- **HTTP hygiene**: Enforce basic request sanity (method, headers, body size)
- **Minimal operational overhead**: No per-service tuning, fail-open posture
- **Observable blocking**: WAF decisions visible via Prometheus metrics and Hubble flows
- **Lifecycle safety**: WAF never becomes a dependency for cluster operations

### Non-Goals

- Enterprise-grade virtual patching or comprehensive security
- Internal gateway protection (Tailscale traffic is trusted)
- Per-service or stateful WAF tuning
- East–west traffic inspection

### Technology Choice

**Coraza via Istio WasmPlugin CRD**. Rationale:

| Option | Verdict | Reasoning |
|--------|---------|-----------|
| Istio WasmPlugin + coraza-proxy-wasm | ✅ | Native Istio resource, OCI-based distribution, embedded OWASP CRS |
| Raw EnvoyFilter | ❌ | Lower-level complexity, harder to maintain |
| Tetrate Envoy Gateway Helm | ❌ | Replaces Istio as Gateway API impl—not compatible with current setup |
| Sidecar-based WAF | ❌ | Per-pod overhead, conflicts with ambient mode |

---

## Architecture

### Gateway Topology (Current State)

The homelab uses a two-gateway model, both deployed in `istio-gateway` namespace:

| Gateway | Purpose | Hostname Pattern | WAF Protected |
|---------|---------|------------------|---------------|
| `external` | Public internet traffic | `*.${external_domain}` | ✅ Yes |
| `internal` | Tailscale/private traffic | `*.${internal_domain}` | ❌ No (trusted) |

### WAF Placement

```
                    Internet
                        │
                        ▼
┌───────────────────────────────────────────────────────────┐
│                   External Gateway                         │
│                   (istio-gateway ns)                       │
│                                                           │
│   TLS termination                                         │
│        ↓                                                  │
│   Coraza WasmPlugin  ◄── Inspects all HTTP requests      │
│        ↓                                                  │
│   Router → HTTPRoute                                      │
└───────────────────────────────────────────────────────────┘
                        │
                        ▼
              Backend Services (ambient mesh)


                   Tailscale
                        │
                        ▼
┌───────────────────────────────────────────────────────────┐
│                   Internal Gateway                         │
│                   (istio-gateway ns)                       │
│                                                           │
│   TLS termination                                         │
│        ↓                                                  │
│   Router → HTTPRoute  (no WAF - trusted traffic)         │
└───────────────────────────────────────────────────────────┘
                        │
                        ▼
              Backend Services (ambient mesh)
```

### Traffic Coverage

All HTTP traffic through the external gateway is inspected. Non-HTTP traffic naturally bypasses Coraza:

| Traffic Type | WAF Inspection | Notes |
|--------------|----------------|-------|
| HTTP/HTTPS via external gateway | ✅ | All public-facing routes |
| HTTP/HTTPS via internal gateway | ❌ | Trusted Tailscale traffic |
| TCP streams (Jellyfin, game servers) | ❌ | Non-HTTP, Coraza doesn't apply |
| Kubernetes API | ❌ | Not routed through gateways |

---

## Implementation Details

### File Structure

All Coraza resources live alongside existing gateway configuration:

```
kubernetes/platform/config/gateway/
├── external-gateway.yaml      # Existing
├── internal-gateway.yaml      # Existing
├── httproutes/                # Existing
├── coraza-wasm-plugin.yaml    # NEW: WasmPlugin resource
└── coraza-config.yaml         # NEW: ConfigMap with SecLang rules
```

### WasmPlugin Resource

```yaml
apiVersion: extensions.istio.io/v1alpha1
kind: WasmPlugin
metadata:
  name: coraza-waf
  namespace: istio-gateway
spec:
  # Target only the external gateway
  selector:
    matchLabels:
      gateway.networking.k8s.io/gateway-name: external
  url: oci://ghcr.io/corazawaf/coraza-proxy-wasm
  phase: AUTHN  # Run early in filter chain, before auth
  pluginConfig:
    # Reference ConfigMap for SecLang configuration
    directives_map:
      default: |
        Include @coraza.conf-recommended
        Include @crs-setup.conf.example
        Include @owasp_crs/*.conf
        SecRuleEngine On
  failStrategy: FAIL_OPEN  # Don't block traffic if WAF errors
```

### ConfigMap for Rule Tuning

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coraza-rules
  namespace: istio-gateway
data:
  custom-rules.conf: |
    # Paranoia level 1 (lowest, fewer false positives)
    SecAction "id:900000,phase:1,pass,t:none,nolog,setvar:tx.blocking_paranoia_level=1"

    # Disable specific rules that cause false positives
    # SecRuleRemoveById 920350  # Example: Host header validation

    # Request body size limit (10MB)
    SecRequestBodyLimit 10485760
    SecRequestBodyNoFilesLimit 131072

    # Response body inspection disabled (performance)
    SecResponseBodyAccess Off
```

### Prometheus Metrics

Coraza exposes metrics via the Envoy stats endpoint. Key metrics to monitor:

| Metric | Description |
|--------|-------------|
| `waf_requests_total` | Total requests processed |
| `waf_blocked_total` | Requests blocked by WAF |
| `waf_rule_hits_total{rule_id}` | Hits per CRS rule |
| `waf_latency_seconds` | Processing time overhead |

These are exposed through Istio's proxy metrics and scraped by Prometheus.

### Hubble Integration

Hubble provides L3/L4 visibility complementing WAF's L7 inspection:

- **Flow logs**: See connection patterns to/from external gateway
- **Dropped flows**: Correlate with WAF blocks
- **Network policy enforcement**: Verify WAF sits in expected path

---

## Configuration Management

### SecLang Rule Customization

The ConfigMap allows iterative tuning without redeploying the WASM binary:

1. **Initial deployment**: Use embedded CRS defaults
2. **Monitor false positives**: Check `waf_blocked_total` and application logs
3. **Add exclusions**: Update ConfigMap with `SecRuleRemoveById` directives
4. **Tune paranoia**: Adjust `blocking_paranoia_level` if needed

### Version Management

| Component | Source | Update Strategy |
|-----------|--------|-----------------|
| coraza-proxy-wasm | `ghcr.io/corazawaf/coraza-proxy-wasm` | Renovate updates WasmPlugin image tag |
| OWASP CRS | Embedded in WASM binary | Updates with coraza-proxy-wasm releases |
| Custom rules | ConfigMap in git | Manual updates via PR |

---

## Lifecycle Safety

### Protected Operations

These must work even if Coraza, Istio, or Gateway API is broken:

- Kubernetes API access (not routed through gateways)
- kubeconfig generation (Talos API)
- Terragrunt operations (direct API access)
- Cluster teardown
- Node provisioning and PXE boot

### Failure Modes

| Failure | Behavior | Recovery |
|---------|----------|----------|
| WASM binary unavailable | Traffic passes (FAIL_OPEN) | Flux reconciles, pulls image |
| ConfigMap invalid | WAF uses embedded defaults | Fix ConfigMap, Flux reconciles |
| High latency | Consider FAIL_OPEN timeout | Investigate rule complexity |
| False positives blocking users | Add rule exclusion to ConfigMap | PR and merge |

---

## Implementation Phases

### Phase 1: Foundation

- [ ] Add `coraza-wasm-plugin.yaml` to `kubernetes/platform/config/gateway/`
- [ ] Add `coraza-config.yaml` ConfigMap with baseline SecLang rules
- [ ] Update gateway kustomization to include new resources
- [ ] Verify WasmPlugin pulls OCI image successfully

### Phase 2: Validation

- [ ] Test common attack patterns are blocked (SQLi, XSS, path traversal)
- [ ] Test legitimate application traffic passes without errors
- [ ] Verify fail-open behavior (delete WasmPlugin, traffic still flows)
- [ ] Measure latency overhead (target: < 5ms p99)

### Phase 3: Observability

- [ ] Verify Coraza metrics appear in Prometheus
- [ ] Create Grafana dashboard: block rate, top triggered rules, latency
- [ ] Configure alert for sustained high block rate
- [ ] Document Hubble queries for WAF-related flow analysis

### Phase 4: Tuning

- [ ] Monitor for false positives over 1-week soak period
- [ ] Add rule exclusions to ConfigMap as needed
- [ ] Document any application-specific tuning in ConfigMap comments
- [ ] Establish runbook for adding new exclusions

---

## Success Criteria

- Coraza blocks common scanner noise and malformed requests
- Legitimate application traffic passes without increased latency (< 5ms p99 overhead)
- WAF metrics visible in Prometheus/Grafana
- Fail-open behavior verified: traffic flows when WASM binary unavailable
- False positive rate < 0.1% of legitimate traffic after tuning
- Cluster operations (destroy, provision) succeed with WAF deployed

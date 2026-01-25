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
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/extensions.istio.io/wasmplugin_v1alpha1.json
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
  # Pin to digest for supply chain security
  # renovate: datasource=docker depName=ghcr.io/corazawaf/coraza-proxy-wasm
  url: oci://ghcr.io/corazawaf/coraza-proxy-wasm:v0.7.0@sha256:abc123...
  imagePullPolicy: IfNotPresent
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

> **Security Note**: The `failStrategy: FAIL_OPEN` allows traffic when WAF errors occur. This is intentional (availability over security), but requires alerting to detect silent failures. See PrometheusRule below.

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
| `envoy_wasm_envoy_wasm_runtime_null_active` | WASM runtime health (0 = degraded) |

These are exposed through Istio's proxy metrics and scraped by Prometheus.

### PrometheusRule for Alerting

```yaml
# yaml-language-server: $schema=https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/monitoring.coreos.com/prometheusrule_v1.json
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: coraza-waf
  namespace: istio-gateway
spec:
  groups:
    - name: coraza-waf
      rules:
        # Alert if WAF is in FAIL_OPEN state (processing errors)
        - alert: CorazaWAFDegraded
          expr: |
            sum(rate(envoy_wasm_envoy_wasm_runtime_null_active{pod=~"external-gateway.*"}[5m])) == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Coraza WAF is degraded on external gateway"
            description: "WAF WASM runtime is not active. Traffic is passing unfiltered (FAIL_OPEN)."

        # Alert on sustained high block rate (potential attack or false positives)
        - alert: CorazaWAFHighBlockRate
          expr: |
            sum(rate(waf_blocked_total{pod=~"external-gateway.*"}[5m]))
            / sum(rate(waf_requests_total{pod=~"external-gateway.*"}[5m])) > 0.1
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Coraza WAF blocking >10% of traffic"
            description: "High block rate may indicate attack or false positives. Review waf_rule_hits_total."

        # Alert if WAF latency is impacting user experience
        - alert: CorazaWAFHighLatency
          expr: |
            histogram_quantile(0.99, sum(rate(waf_latency_seconds_bucket{pod=~"external-gateway.*"}[5m])) by (le)) > 0.05
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Coraza WAF p99 latency >50ms"
            description: "WAF processing overhead is high. Consider rule optimization."
```

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

## Verification Commands

Concrete commands for validating each implementation phase:

### Phase 1 Verification
```bash
# Verify WasmPlugin is created and image pulled
kubectl -n istio-gateway get wasmplugins coraza-waf -o yaml
kubectl -n istio-gateway get pods -l gateway.networking.k8s.io/gateway-name=external -o jsonpath='{.items[*].status.containerStatuses[*].ready}'

# Check WasmPlugin is attached to gateway
istioctl proxy-config listeners external-gateway-xxx -n istio-gateway | grep -i wasm
```

### Phase 2 Verification
```bash
# Test common attack patterns are blocked
curl -I "https://app.example.com/?id=1'%20OR%20'1'='1"  # SQLi - expect 403
curl -I "https://app.example.com/?q=<script>alert(1)</script>"  # XSS - expect 403
curl -I "https://app.example.com/../../../etc/passwd"  # Path traversal - expect 403

# Test legitimate traffic passes
curl -I "https://app.example.com/"  # Normal request - expect 200

# Verify fail-open behavior
kubectl -n istio-gateway delete wasmplugin coraza-waf
curl -I "https://app.example.com/"  # Should still return 200
kubectl -n istio-gateway apply -f coraza-wasm-plugin.yaml  # Restore

# Measure latency overhead
kubectl -n istio-gateway exec -it deploy/external-gateway -- curl -w "@/dev/stdin" -o /dev/null -s "http://localhost:15000/stats/prometheus" <<< "time_total: %{time_total}\n"
```

### Phase 3 Verification
```bash
# Verify metrics in Prometheus
kubectl -n prometheus port-forward svc/prometheus 9090:9090 &
curl -s "http://localhost:9090/api/v1/query?query=waf_requests_total" | jq '.data.result'
curl -s "http://localhost:9090/api/v1/query?query=waf_blocked_total" | jq '.data.result'

# Verify PrometheusRule is loaded
kubectl -n istio-gateway get prometheusrules coraza-waf
kubectl -n prometheus exec -it deploy/prometheus -- promtool check rules /etc/prometheus/rules/*.yaml
```

---

## Rollback Procedures

### Immediate Rollback (Traffic Impact)

If WAF is blocking legitimate traffic:

```bash
# Option 1: Disable WAF entirely (safest)
kubectl -n istio-gateway delete wasmplugin coraza-waf

# Option 2: Switch to detection-only mode
kubectl -n istio-gateway patch configmap coraza-rules --type=merge -p '
data:
  custom-rules.conf: |
    SecRuleEngine DetectionOnly
'

# Verify traffic flows
curl -I "https://app.example.com/"
```

### Rule-Specific Rollback

If specific rules cause false positives:

```bash
# Identify offending rule from metrics
kubectl -n prometheus port-forward svc/prometheus 9090:9090 &
curl -s "http://localhost:9090/api/v1/query?query=topk(5,waf_rule_hits_total)" | jq '.data.result'

# Add exclusion to ConfigMap (then commit via PR)
kubectl -n istio-gateway patch configmap coraza-rules --type=merge -p '
data:
  custom-rules.conf: |
    SecAction "id:900000,phase:1,pass,t:none,nolog,setvar:tx.blocking_paranoia_level=1"
    SecRuleRemoveById 920350  # Disable specific rule
'
```

### Full Rollback via Git

```bash
# Revert the PR that added Coraza
git revert <commit-sha>
git push origin main

# Flux will reconcile and remove WasmPlugin
flux reconcile kustomization platform --with-source
```

---

## Success Criteria

- Coraza blocks common scanner noise and malformed requests
- Legitimate application traffic passes without increased latency (< 5ms p99 overhead)
- WAF metrics visible in Prometheus/Grafana
- Fail-open behavior verified: traffic flows when WASM binary unavailable
- CorazaWAFDegraded alert fires when WAF is in fail-open state
- False positive rate < 0.1% of legitimate traffic after tuning
- Cluster operations (destroy, provision) succeed with WAF deployed

---

## Implementation Learnings

**Added after dev cluster validation testing (January 2026)**

### Correct WASM Image Digest

The coraza-proxy-wasm image digest must be verified at deployment time. The actual digest for v0.6.0 is:

```
sha256:65d6009b9da2e8965e592a08b74a86725435fc01aa39c756dce0bd5ea64b3f4e
```

> **Warning**: If the digest is wrong, Istio logs: `module downloaded has checksum X, which does not match Y`. The FAIL_OPEN strategy allows traffic but WAF is not filtering.

### Actual Metrics (vs. Documented)

The plan originally referenced metrics like `waf_requests_total` and `waf_blocked_total`. Actual Coraza metrics exported:

| Documented | Actual |
|------------|--------|
| `waf_requests_total` | Use `istio_requests_total{source_workload=~"external-istio"}` |
| `waf_blocked_total` | Use `istio_requests_total{..., response_code="403"}` |
| `waf_rule_hits_total{rule_id}` | `waf_filter_tx_interruptions_ruleid_<RULE_ID>_phase_<PHASE>` |
| `waf_latency_seconds` | Use `istio_request_duration_milliseconds` |

**Recommendation**: Use standard Istio metrics for alerting (always present), supplement with Coraza-specific `waf_filter_tx_*` metrics for rule debugging.

### SNI Requirement for Testing

Istio's gateway listener uses SNI (Server Name Indication) matching. Testing with raw IP addresses fails:

```bash
# WRONG - no SNI, connection reset
curl -kI "https://192.168.10.53/"

# CORRECT - SNI sent via --resolve
curl -kI --resolve "kromgo.external.dev.tomnowak.work:443:192.168.10.53" \
  "https://kromgo.external.dev.tomnowak.work/"
```

### Validated Test Results

From dev cluster testing:

| Test | Expected | Actual |
|------|----------|--------|
| SQLi (`?id=1' OR '1'='1`) | 403 | ✅ 403 |
| XSS (`?q=<script>alert(1)`) | 403 | ✅ 403 |
| Command Injection (`?cmd=;cat /etc/passwd`) | 403 | ✅ 403 |
| Normal request | 200 | ✅ 200 |
| Internal gateway (SQLi) | Not 403 | ✅ 404 (no WAF) |
| WAF deleted → traffic flows | 200 | ✅ 200 |
| Invalid SHA → FAIL_OPEN | 200 | ✅ 200 |
| p99 latency | < 50ms | ✅ 29ms |

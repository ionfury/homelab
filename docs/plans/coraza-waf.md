# Coraza WAF Implementation Strategy

## 1. Scope and Intent

**Goal**
Provide lightweight HTTP hygiene and exploit noise reduction for unauthenticated ingress traffic in a homelab Kubernetes cluster.

**Explicit non-goals**
- Enterprise-grade virtual patching
- East–west traffic inspection
- Sidecar-based WAF
- Per-service or stateful WAF tuning
- TCP or streaming traffic inspection (e.g., Jellyfin)

---

## 2. Architectural Placement

### Control Plane
- Kubernetes cluster managed by Talos
- Ingress implemented using Istio
- Ingress routing defined via Kubernetes Gateway API (`Gateway`, `HTTPRoute`)

### WAF Placement (Critical)
- Coraza runs **only** at the Istio ingress gateway
- Implemented as a WASM HTTP filter in Envoy
- Injected via Istio `EnvoyFilter`
- Never runs in:
  - Sidecars
  - Ambient waypoints
  - East–west traffic
  - Storage or infrastructure namespaces

---

## 3. CRDs and APIs

### Actively Used
- `Gateway` (Gateway API)
- `HTTPRoute` (Gateway API)
- `EnvoyFilter` (Istio)
- Optional:
  - `AuthorizationPolicy`
  - `RequestAuthentication`

### Explicitly Not Used for Ingress
- `VirtualService`
- `DestinationRule`

Gateway API is the ingress **contract**; Istio is the **implementation**.

---

## 4. Traffic Coverage Rules

### WAF Applies To
- HTTP/HTTPS traffic
- Unauthenticated or publicly reachable endpoints
- Selected hosts or routes only

### WAF Explicitly Excludes
- Jellyfin and other streaming endpoints
- Long-lived or high-bandwidth connections
- TCP services
- Authenticated internal APIs (unless explicitly opted in)

**Scoping mechanisms**
- Separate Gateways, or
- Hostname-based matching in the `EnvoyFilter`

---

## 5. Envoy Filter Ordering (Required)

The Coraza filter must appear in the Envoy HTTP filter chain in the following order:

LS termination
→ Rate limiting (if used)
→ Coraza WAF (WASM)
→ Authentication / Authorization (optional)
→ Router


This preserves visibility into raw requests and avoids masking failures.

---

## 6. Coraza Configuration Posture

### Rule Set
- OWASP Core Rule Set (CRS)
- Low paranoia level
- Fail-open behavior preferred

### Enabled Capabilities
- HTTP method sanity checks
- Header normalization
- Request body size limits
- Generic exploit pattern blocking

### Explicitly Disabled or Avoided
- Aggressive CRS tuning
- Stateful inspection
- Per-service rule customization
- Detailed audit logging

The WAF is intended for noise reduction, not comprehensive security.

---

## 7. Istio Mode Compatibility

- Works with both:
  - Classic Istio
  - Ambient Istio
- Ambient mesh does not change ingress behavior
- Coraza is never deployed to:
  - Ambient waypoints
  - ztunnel paths

Ingress gateways always run classic Envoy.

---

## 8. Lifecycle and Teardown Safety

- Coraza must never be required for:
  - Cluster reachability
  - kubeconfig generation
  - Terraform destroy operations
- If Istio, Coraza, or Gateway API objects are removed or broken:
  - Cluster teardown must still succeed
- Coraza is treated as ephemeral application infrastructure

---

## 9. Implementation Checklist

1. Install Kubernetes Gateway API CRDs
2. Deploy Istio ingress gateway
3. Define ingress using `Gateway` and `HTTPRoute`
4. Deploy Coraza via an Istio `EnvoyFilter`:
   - Scoped to ingress gateway workload
   - WASM-based HTTP filter
   - Correct filter ordering
5. Scope WAF to selected hosts or routes
6. Explicitly bypass Jellyfin and other streaming services
7. Keep configuration minimal and fail-open

---

## 10. One-Sentence Summary

**Coraza is a gateway-only, WASM-based HTTP WAF implemented via Istio `EnvoyFilter`, applied selectively to unauthenticated ingress defined with Kubernetes Gateway API, and deliberately excluded from sidecars, ambient waypoints, and critical cluster lifecycle paths.**

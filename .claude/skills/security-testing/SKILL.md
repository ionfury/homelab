---
name: security-testing
description: |
  Adversarial security testing methodology for the Kubernetes homelab. Covers network policy
  evasion, authentication bypass, privilege escalation, credential theft, and supply chain attacks.

  Use when: (1) Red team testing against the homelab, (2) Validating network policy enforcement,
  (3) Testing WAF bypass on external gateway, (4) Probing authentication layers,
  (5) Assessing container escape paths, (6) Auditing RBAC and service accounts,
  (7) Testing supply chain security of OCI promotion pipeline.

  Triggers: "security test", "red team", "pentest", "penetration test", "attack surface",
  "WAF bypass", "network policy evasion", "privilege escalation", "lateral movement",
  "credential theft", "container escape", "RBAC audit", "security audit", "vulnerability"
user-invocable: false
---

# Security Testing Methodology

**AUTHORIZED SCOPE**: Dev cluster only. Integration and live clusters are read-only per CLAUDE.md.

See [references/attack-surface.md](references/attack-surface.md) for the full inventory of known weaknesses, exploitation notes, and severity ratings per layer (Network, Gateway, Auth, Authorization, Container, Supply Chain, Credential).

All bash commands are in [references/test-commands.md](references/test-commands.md).

---

## Phase 1: Network Policy Testing

Test intra-namespace lateral movement (the `baseline-intra-namespace` CCNP allows free pod-to-pod communication within a namespace — expect full access). Test cross-namespace escape by verifying that `isolated` and `internal` profile pods cannot reach other namespaces or the internet (DNS always succeeds — this is a known exfiltration path). Test Prometheus label impersonation: if the `baseline-prometheus-scrape` CCNP uses label-only matching, any pod with the right label can bypass namespace boundaries (NET-001). Test escape hatch abuse by enumerating which service accounts can label namespaces.

Commands: see [references/test-commands.md#phase-1-network-policy-testing](references/test-commands.md#phase-1-network-policy-testing)

---

## Phase 2: Authentication & WAF Testing

Test Coraza WAF bypass using double-encoding and JSON body SQLi — the OWASP CRS at Paranoia Level 1 blocks standard patterns but may miss encoding variations. Verify WAF FAIL_OPEN: if `coraza_waf_requests_total` returns no results, the WASM module may have failed and traffic is unfiltered (GW-001). Test the Vaultwarden admin panel: the HTTPRoute redirect operates at the gateway but direct pod IP access bypasses it entirely. Inspect OAuth2-Proxy cookies for missing `httponly`, `samesite`, or short expiry.

Commands: see [references/test-commands.md#phase-2-authentication--waf-testing](references/test-commands.md#phase-2-authentication--waf-testing)

---

## Phase 3: Privilege Escalation

Enumerate pods with automounted service account tokens — the `homepage` SA has cluster-wide read access (AUTHZ-001). Scan for containers running as root or with elevated capabilities. Identify pods opted out of the Istio mesh (no mTLS protection). Enumerate RBAC bindings that reach the `external-secrets-access-key` in `kube-system`: it's a static AWS IAM key with read access to all SSM parameters (CRED-001). Test whether the Garage S3 admin API is reachable from the gateway pod.

Commands: see [references/test-commands.md#phase-3-privilege-escalation](references/test-commands.md#phase-3-privilege-escalation)

---

## Phase 4: Data Exfiltration Paths

DNS tunneling works from any namespace including `isolated` — base64-encode data into subdomain queries. Prometheus is reachable from the monitoring namespace without auth and exposes full service topology and node inventory via the API. Loki allows unauthenticated push from any pod that can reach it (monitoring CNP allows `fromEntities: cluster` on port 3100).

Commands: see [references/test-commands.md#phase-4-data-exfiltration-paths](references/test-commands.md#phase-4-data-exfiltration-paths)

---

## Phase 5: Supply Chain

Enumerate Flux sources and receivers to understand where git credentials and webhook tokens are stored. Probe the PXE boot service — it is reachable from any namespace and could serve malicious iPXE scripts if compromised.

Commands: see [references/test-commands.md#phase-5-supply-chain](references/test-commands.md#phase-5-supply-chain)

---

## Cleanup

Run after every test session:

```bash
kubectl --context dev delete pod sectest fake-prom -n <ns> --ignore-not-found
kubectl --context dev delete httproute sectest-route-injection -n <ns> --ignore-not-found
kubectl --context dev label namespace <ns> network-policy.homelab/enforcement- 2>/dev/null
kubectl --context dev get pods -A | grep sectest
```

---

## Finding Severity Guide

See [references/attack-surface.md](references/attack-surface.md#finding-severity-guide) for the severity classification table (Critical/High/Medium/Low/Informational).

---

## Cross-References

- [references/attack-surface.md](references/attack-surface.md) — Known weaknesses inventory (NET, GW, AUTH, AUTHZ, CTR, CRED, SC layers)
- [references/test-commands.md](references/test-commands.md) — All bash commands organized by phase
- [network-policy SKILL](../network-policy/SKILL.md) — Cilium policy architecture
- [gateway-routing SKILL](../gateway-routing/SKILL.md) — Gateway API, TLS, WAF configuration
- [k8s SKILL](../k8s/SKILL.md) — Cluster access patterns

## Keywords

security testing, red team, penetration testing, network policy evasion, WAF bypass, authentication bypass, privilege escalation, lateral movement, container escape, RBAC audit, credential theft, supply chain attack, DNS tunneling, log injection

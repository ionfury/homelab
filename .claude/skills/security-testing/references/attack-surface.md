# Homelab Attack Surface Inventory

Known weaknesses and attack vectors specific to this homelab infrastructure. Each entry includes the design rationale (when it's intentional) and exploitation potential.

---

## Network Layer

### NET-001: Prometheus Scrape Baseline — Unrestricted Port Access

**Component**: `baseline-prometheus-scrape` CCNP
**Path**: `kubernetes/platform/config/network-policy/baselines/`

The Prometheus scrape baseline allows the Prometheus pod to reach ANY pod on ANY port cluster-wide. The `fromEndpoints` selector matches on pod labels without `toPorts` restriction.

- **Exploitation**: If a pod can impersonate the Prometheus label (`app.kubernetes.io/name=prometheus`), it bypasses all network policies for egress
- **Mitigation check**: Does the CCNP scope to `io.kubernetes.pod.namespace: monitoring`? If yes, label impersonation is insufficient
- **Severity**: High (if namespace-unscoped) / Low (if namespace-scoped)

### NET-002: Escape Hatch 5-Minute Detection Window

**Component**: `escape-hatch-allow-all` CCNP + `NetworkPolicyEnforcementDisabled` alert
**Path**: `kubernetes/platform/config/network-policy/baselines/escape-hatch-allow-all.yaml`

Labeling a namespace `network-policy.homelab/enforcement=disabled` grants unrestricted traffic. The alert only fires after 5 minutes.

- **Exploitation**: 5-minute window of unrestricted access before detection
- **RBAC requirement**: Must be able to label namespaces (check which SAs have this)
- **Design rationale**: Intentional emergency escape hatch
- **Severity**: Medium (requires namespace label RBAC)

### NET-003: Intra-Namespace Free Communication

**Component**: `baseline-intra-namespace` CCNP
**Path**: `kubernetes/platform/config/network-policy/baselines/intra-namespace.yaml`

All pods within a namespace can communicate freely on any port.

- **Exploitation**: Compromise one pod → lateral movement to all pods in the namespace
- **Design rationale**: Intentional — simplifies service-to-service communication
- **Severity**: Medium (limited to namespace scope)

### NET-004: DNS Always Available (Tunneling)

**Component**: `baseline-dns-egress` CCNP

Every pod can reach DNS (UDP/TCP 53). DNS tunneling encodes arbitrary data in subdomain queries.

- **Exploitation**: Data exfiltration from any pod, including `isolated` profile
- **Design rationale**: DNS is required for basic Kubernetes operation
- **Detection**: Would require DNS query anomaly detection (not currently monitored)
- **Severity**: Low (slow, detectable with proper monitoring)

---

## Gateway Layer

### GW-001: WAF FAIL_OPEN Strategy

**Component**: Coraza WasmPlugin on external gateway
**Path**: `kubernetes/platform/config/gateway-routing/`

The WAF uses `failStrategy: FAIL_OPEN`. If the WASM module is unavailable (OCI pull failure, crash, resource exhaustion), all traffic flows unfiltered.

- **Exploitation**: Cause WAF module failure → all external traffic bypasses WAF
- **Alert**: `CorazaWAFDegraded` monitors for missing metrics, but doesn't detect the specific fail-open condition
- **Design rationale**: Documented choice — "availability over security"
- **Severity**: High (removes entire WAF layer)

### GW-002: Paranoia Level 1 (Lowest WAF Sensitivity)

**Component**: Coraza CRS configuration

OWASP CRS at PL1 has limited coverage. Known bypasses include double-encoding, chunked transfer, unicode normalization, and JSON payload injection.

- **Exploitation**: Standard WAF bypass techniques against PL1
- **Design rationale**: PL1 minimizes false positives for a homelab
- **Severity**: Medium (WAF still catches basic attacks)

### GW-003: Gateway allowedRoutes.from: All

**Component**: Both Istio Gateways (external + internal)

Any namespace can attach an HTTPRoute to either gateway, potentially exposing internal services externally.

- **Exploitation**: Create an HTTPRoute in any namespace → expose arbitrary backend through the gateway
- **RBAC requirement**: Must be able to create HTTPRoute resources
- **Severity**: High (can expose internal services to the internet)

---

## Authentication Layer

### AUTH-001: OAuth2-Proxy 7-Day Cookie

**Component**: OAuth2-Proxy configuration

The `_oauth2_proxy` cookie has a 168-hour (7-day) lifetime with `SameSite=Lax`.

- **Exploitation**: Captured cookie is valid for 7 days. `SameSite=Lax` allows replay from cross-site GET requests
- **Severity**: Low (requires cookie capture, which requires separate vulnerability)

### AUTH-002: Vaultwarden Admin Redirect is Gateway-Level

**Component**: Vaultwarden HTTPRoute

The `/admin` path is redirected to `/` via HTTPRoute filter. The Vaultwarden pod still serves the admin endpoint.

- **Exploitation**: Direct pod access (bypassing gateway) reaches `/admin`. Path variations (`/admin/`, `/Admin`) may bypass the redirect
- **Severity**: Medium (requires intra-cluster access or path bypass)

### AUTH-003: Authelia Brute Force Parameters

**Component**: Authelia regulation config

3 retries in 2 minutes, 5-minute ban. Alert at 30% failure rate over 10 minutes.

- **Exploitation**: Slow credential stuffing (1 attempt per 2 minutes) stays under all detection thresholds
- **Per-IP vs per-user**: Needs verification — if per-IP, source rotation bypasses ban
- **Severity**: Low (Authelia requires 2FA, making password-only attacks insufficient)

---

## Authorization Layer

### AUTHZ-001: Homepage ClusterRole — Cluster-Wide Read

**Component**: `homepage` ClusterRole + ClusterRoleBinding

The homepage ServiceAccount can read namespaces, pods, nodes, metrics, HTTPRoutes, and gateways cluster-wide.

- **Exploitation**: Compromised homepage pod → enumerate full cluster topology, all pod names, node IPs, all routes
- **Severity**: Low (read-only, but valuable for reconnaissance)

### AUTHZ-002: Prometheus Admin API Enabled

**Component**: kube-prometheus-stack configuration (`enableAdminAPI: true`)

The Prometheus admin API allows snapshot creation, series deletion, and other admin operations. Protected only by OAuth2-Proxy on the internal gateway.

- **Exploitation**: Authenticated internal user can delete metrics data, create snapshots, or manipulate Prometheus state
- **Severity**: Medium (requires authenticated access)

---

## Container Layer

### CTR-001: Gluetun — Root, NET_ADMIN, No Mesh

**Component**: qBittorrent Gluetun sidecar in media namespace

Runs as root with NET_ADMIN + NET_RAW capabilities, explicitly opted out of Istio mesh (`istio.io/dataplane-mode: none`), and has unrestricted world egress via `media-qbittorrent-egress` CNP.

- **Exploitation**: Compromise → root container with full internet access and no mTLS, bypassing all mesh security
- **Design rationale**: WireGuard VPN requires NET_ADMIN and root for tunnel creation
- **Severity**: High (most privileged non-system container)

### CTR-002: Cilium Agent Capabilities

**Component**: Cilium agent DaemonSet

Runs with SYS_ADMIN, BPF, NET_ADMIN, NET_RAW, and several other elevated capabilities.

- **Exploitation**: Compromise → eBPF access, network interception, packet manipulation on the node
- **Design rationale**: Required for Cilium CNI operation
- **Severity**: Critical (but exploitation requires breaking into the Cilium agent specifically)

---

## Credential Layer

### CRED-001: Static AWS IAM Key

**Component**: `external-secrets-access-key` Secret in `kube-system`

Static long-lived AWS IAM key with read access to all SSM parameters under `/homelab/kubernetes/`.

- **SSM contents**: Cloudflare API token, GitHub OAuth secrets, NordVPN credentials, Istio mesh CA private key
- **Exploitation**: Read this secret → access all secrets in AWS SSM → full credential theft
- **Severity**: Critical (keys to the kingdom)

### CRED-002: Garage S3 Admin API from Gateway Namespace

**Component**: Garage admin port 3903, network policy allows istio-gateway access

The Garage admin API is reachable from the istio-gateway namespace.

- **Exploitation**: Compromised gateway pod → list/create/delete S3 buckets, manage access keys, read stored objects
- **Severity**: High (full S3 admin access)

---

## Supply Chain Layer

### SC-001: Integration Auto-Deploy

**Component**: OCI promotion pipeline, Flux ImagePolicy

Any OCI artifact tagged `integration-*` auto-deploys to the integration cluster.

- **Exploitation**: Push a malicious artifact to GHCR with an `integration-*` tag → auto-deployed
- **RBAC requirement**: Must have GHCR push access (GitHub token)
- **Severity**: High (arbitrary code execution on integration)

### SC-002: PXE Boot Shell Option

**Component**: PXE boot server, iPXE menu

The iPXE menu includes a `shell` option accessible from the cluster node subnet.

- **Exploitation**: L2 access to cluster subnet → PXE boot → iPXE shell → potential cluster join
- **Severity**: Medium (requires physical/L2 network access)

### SC-003: Metrics-Server Insecure TLS

**Component**: metrics-server with `--kubelet-insecure-tls`

Skips kubelet serving certificate validation, creating an MITM opportunity.

- **Exploitation**: MITM on kubelet-to-metrics-server path → inject false resource metrics
- **Design rationale**: Standard pattern for Talos clusters with self-signed kubelet certs
- **Severity**: Low (requires network-level MITM within cluster)

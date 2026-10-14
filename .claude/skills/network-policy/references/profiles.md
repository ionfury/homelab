# Network Policy Reference

## Architecture Quick Reference

All cluster traffic is **implicitly denied** via Cilium baseline CCNPs. Two layers control access:

1. **Baselines** (cluster-wide CCNPs): DNS egress, health probes, Prometheus scrape, opt-in kube-API
2. **Profiles** (per-namespace via label): ingress/egress rules matched by `network-policy.homelab/profile=<value>`

Platform namespaces (`kube-system`, `monitoring`, `database`, etc.) use hand-crafted CNPs — **never** apply profiles to them.

## Profile Selection

| Profile | Ingress | Egress | Use Case |
|---------|---------|--------|----------|
| `isolated` | None | DNS only | Batch jobs, workers |
| `internal` | Internal gateway | DNS only | Internal dashboards |
| `internal-egress` | Internal gateway | DNS + HTTPS | Internal apps calling external APIs |
| `standard` | Both gateways | DNS + HTTPS | Public-facing web apps |

**Decision tree:**
- App needs to be reached from the internet? -> `standard`
- Internal-only but needs to call external APIs? -> `internal-egress`
- Internal-only, no external calls? -> `internal`
- No ingress at all? -> `isolated`

## Access Label Catalog

Add to the namespace in `kubernetes/platform/namespaces.yaml`:

| Label | Port | Resource | Notes |
|-------|------|---------|-------|
| `access.network-policy.homelab/postgres: "true"` | 5432 | PostgreSQL (shared platform cluster) | Add to requesting namespace |
| `access.network-policy.homelab/dragonfly: "true"` | 6379 | Dragonfly/Redis cache | Add to requesting namespace |
| `access.network-policy.homelab/garage-s3: "true"` | 3900 | Garage S3 object storage | Add to requesting namespace |
| `access.network-policy.homelab/kube-api: "true"` | 6443 | Kubernetes API | Add to requesting namespace |
| `access.network-policy.homelab/home-assistant: "true"` | per-app | Allows HA egress into this namespace | Add to TARGET app namespace |

> **`home-assistant` label — inverted semantics.** Unlike the other labels (which go on the requester and
> grant fixed-port egress to a platform service), this label goes on the **target app namespace** and
> allows Home Assistant to reach that app. The shared CCNP (`access-home-assistant.yaml`) is L3-only
> (no `toPorts`); the actual port is enforced by a per-app `CiliumNetworkPolicy` in the target namespace
> granting ingress from the `home-assistant` namespace on the app's API port. Cilium intersects both
> rules — the effective allowed port is what the per-app ingress CNP declares.
> Two changes are required per integration: (1) add this label to the target app namespace, and
> (2) create a per-app ingress CNP pinning the app's API port.

## Drop Classification

| Drop Pattern | Likely Cause | Fix |
|---|---|---|
| Egress to `kube-system:53` dropped | Missing DNS baseline | Should not happen — check if baseline CCNP exists |
| Egress to `database:5432` dropped | Missing postgres access label | Add `access.network-policy.homelab/postgres=true` |
| Egress to `database:6379` dropped | Missing dragonfly access label | Add `access.network-policy.homelab/dragonfly=true` |
| Egress to internet `:443` dropped | Profile doesn't allow HTTPS egress | Switch to `internal-egress` or `standard` |
| Ingress from `istio-gateway` dropped | Profile doesn't allow gateway ingress | Switch to `internal`, `internal-egress`, or `standard` |
| Ingress from `monitoring:prometheus` dropped | Missing baseline | Should not happen — check baseline CCNP |
| HA egress to app namespace dropped | Target app namespace missing `access.network-policy.homelab/home-assistant=true` AND/OR missing per-app ingress CNP | Add the label to the target namespace and create a per-app CNP allowing ingress from `home-assistant` on the app's API port |

## Hubble Debug Commands

See [`scripts/hubble-debug.sh`](../scripts/hubble-debug.sh) for the full interactive debug sequence.

```bash
# All drops in a namespace
hubble observe --verdict DROPPED --namespace my-app --since 5m

# With src/dst/port details
hubble observe --verdict DROPPED --namespace my-app --since 5m -o json | \
  jq '{src: .source.namespace + "/" + .source.pod_name, dst: .destination.namespace + "/" + .destination.pod_name, port: (.l4.TCP.destination_port // .l4.UDP.destination_port)}'

# Specific flow checks
hubble observe --namespace my-app --protocol UDP --port 53 --since 5m        # DNS
hubble observe --namespace my-app --to-namespace database --port 5432 --since 5m  # DB
hubble observe --namespace my-app --to-identity world --port 443 --since 5m  # Internet egress
hubble observe --from-namespace istio-gateway --to-namespace my-app --since 5m    # Gateway ingress
hubble observe --from-namespace monitoring --to-namespace my-app --since 5m  # Prometheus scrape
```

## Debugging with Hubble (Full Reference)

### Check for Dropped Traffic

```bash
# Real-time drops
hubble observe --verdict DROPPED --since 5m

# Drops in a specific namespace
hubble observe --verdict DROPPED --namespace my-app --since 5m

# Show source and destination details
hubble observe --verdict DROPPED --since 5m -o json | jq '.source, .destination'
```

### Verify Specific Flows

```bash
# DNS traffic from a namespace
hubble observe --namespace my-app --protocol UDP --port 53 --since 5m

# Prometheus scraping
hubble observe --from-namespace monitoring --to-namespace my-app --since 5m

# Internet egress
hubble observe --namespace my-app --to-identity world --port 443 --since 5m

# Gateway ingress
hubble observe --from-namespace istio-gateway --to-namespace my-app --since 5m
```

### Identify Policy Causing Drops

```bash
# Get drop reasons
hubble observe --verdict DROPPED -o json | jq '.drop_reason_desc'

# Export flows for analysis
hubble observe --namespace my-app --since 1h --output json > /tmp/flows.json

# Summarize unique destinations
cat /tmp/flows.json | \
  jq -r '.destination.namespace + "/" + (.destination.labels // {})["k8s:app.kubernetes.io/name"] + ":" + (.l4.TCP.destination_port // .l4.UDP.destination_port | tostring)' | \
  sort -u
```

### Check Policy Status

```bash
# List all network policies
kubectl get ccnp,cnp -A

# Check Cilium endpoint policy enforcement
kubectl exec -n kube-system cilium-xxxxx -- cilium endpoint list

# Check Cilium agent logs
kubectl logs -n kube-system -l k8s-app=cilium
```

See `docs/runbooks/network-policy-verification.md` for comprehensive verification procedures.

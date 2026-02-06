# L2 to BGP Migration for LoadBalancer IPs

Migrate LoadBalancer IP advertisement from L2 (ARP/NDP) to BGP with minimal downtime.

## Prerequisites

- UniFi router configured with FRR BGP (see [unifi-bgp-configuration.md](unifi-bgp-configuration.md))
- Infrastructure changes deployed (BGP variables in cluster-vars)
- Cilium BGP control plane Helm values committed

## Migration Strategy

The migration uses a **parallel cutover** approach:

1. Deploy BGP resources while L2 remains active
2. BGP sessions establish and routes propagate
3. Remove L2 announcement policy
4. Traffic seamlessly shifts to BGP-advertised routes

This works because both L2 and BGP announce the same IPs. The router prefers BGP routes due to lower administrative distance.

## Pre-Migration Checklist

```
[ ] Infrastructure PRs merged (BGP variables in networking.hcl)
[ ] Cilium Helm values updated (bgpControlPlane.enabled: true)
[ ] BGP CRDs committed (CiliumBGPClusterConfig, CiliumBGPPeerConfig, CiliumBGPAdvertisement)
[ ] UniFi FRR configuration uploaded (verify with: ssh root@192.168.10.1 vtysh -c "show bgp summary")
[ ] Maintenance window scheduled (5-10 minutes expected, rollback plan ready)
```

## Migration Steps

### 1. Verify Current State (L2)

```bash
# Check L2 announcements are working
KUBECONFIG=~/.kube/dev.yaml kubectl get ciliuml2announcementpolicy -A
KUBECONFIG=~/.kube/dev.yaml kubectl get ciliumloadbalancerippool -A

# Check services have IPs
KUBECONFIG=~/.kube/dev.yaml kubectl get svc -A | grep LoadBalancer

# Test connectivity to a LoadBalancer IP
curl -I http://192.168.10.52  # internal ingress
```

### 2. Deploy BGP Configuration

Apply the changes by merging the PR or triggering Flux reconciliation:

```bash
# Force Flux reconciliation on dev cluster
KUBECONFIG=~/.kube/dev.yaml flux reconcile kustomization cilium-config -n flux-system

# Wait for CRDs to be created
KUBECONFIG=~/.kube/dev.yaml kubectl get ciliumbgpclusterconfig,ciliumbgppeerconfig,ciliumbgpadvertisement -A
```

### 3. Verify BGP Sessions Establish

```bash
# Check Cilium BGP peer status
KUBECONFIG=~/.kube/dev.yaml kubectl exec -n kube-system -it ds/cilium -- cilium bgp peers

# Expected output:
# Peer         ASN    State        Uptime
# 192.168.10.1 64512  established  5m0s

# On UniFi router, verify sessions
ssh root@192.168.10.1 vtysh -c "show bgp summary"

# Expected: All node IPs showing "Established" state
```

### 4. Verify BGP Routes Propagating

```bash
# Check advertised routes from Cilium
KUBECONFIG=~/.kube/dev.yaml kubectl exec -n kube-system -it ds/cilium -- cilium bgp routes advertised ipv4 unicast

# On UniFi router, check received routes
ssh root@192.168.10.1 vtysh -c "show ip bgp"
ssh root@192.168.10.1 vtysh -c "show ip route | grep bgp"

# Expected: LoadBalancer IPs appear with BGP protocol
```

### 5. Test Connectivity (BGP Active, L2 Still Present)

At this point both L2 and BGP are advertising the same IPs. Verify services still work:

```bash
# Test internal ingress
curl -I http://192.168.10.52

# Test external ingress
curl -kI --resolve "test.external.dev.tomnowak.work:443:192.168.10.53" \
  "https://test.external.dev.tomnowak.work/"
```

### 6. Remove L2 Announcement Policy

Once BGP is verified working, disable L2 by editing the kustomization:

The L2 policy is already commented out in `kubernetes/platform/config/cilium/kustomization.yaml`:
```yaml
# L2 disabled in favor of BGP (kept for rollback reference)
# - l2.yaml
```

Commit and push this change, then trigger reconciliation:

```bash
KUBECONFIG=~/.kube/dev.yaml flux reconcile kustomization cilium-config -n flux-system

# Verify L2 policy is removed
KUBECONFIG=~/.kube/dev.yaml kubectl get ciliuml2announcementpolicy -A
# Should return: No resources found
```

### 7. Final Verification

```bash
# Verify services still accessible
curl -I http://192.168.10.52

# Verify BGP is the only advertisement mechanism
KUBECONFIG=~/.kube/dev.yaml kubectl exec -n kube-system -it ds/cilium -- cilium bgp peers
KUBECONFIG=~/.kube/dev.yaml kubectl exec -n kube-system -it ds/cilium -- cilium bgp routes advertised ipv4 unicast

# Check router routing table shows BGP routes only
ssh root@192.168.10.1 vtysh -c "show ip route 192.168.10.52"
# Should show: B>* 192.168.10.52/32 [20/0] via 192.168.10.X (not connected/static)
```

## Rollback Procedure

If BGP causes issues, re-enable L2:

### Quick Rollback (Seconds)

1. Edit `kubernetes/platform/config/cilium/kustomization.yaml`
2. Uncomment `- l2.yaml`
3. Commit and push
4. Force reconciliation:
   ```bash
   KUBECONFIG=~/.kube/dev.yaml flux reconcile kustomization cilium-config -n flux-system
   ```

L2 will immediately start announcing IPs via ARP again.

### Full Rollback (Disable BGP Entirely)

1. Comment out BGP resources in kustomization.yaml:
   ```yaml
   # - bgp-peer-config.yaml
   # - bgp-cluster-config.yaml
   # - bgp-advertisement.yaml
   - l2.yaml  # Re-enable L2
   ```

2. Disable BGP control plane in Helm values:
   ```yaml
   bgpControlPlane:
     enabled: false
   ```

3. Remove UniFi BGP configuration:
   ```bash
   ssh root@192.168.10.1
   echo "" > /etc/frr/frr.conf
   systemctl restart frr
   ```

## Post-Migration Monitoring

After migration, monitor for:

| Metric | Source | Expected |
|--------|--------|----------|
| BGP session state | `cilium bgp peers` | All peers "established" |
| Route count | UniFi `show bgp summary` | PfxRcd > 0 for all neighbors |
| Service availability | Canary checks | 100% uptime |
| Failover time | Manual testing | <15s (aggressive timers) |

### Alerting

Consider adding Prometheus alerts for BGP session state:

```yaml
# Example PrometheusRule (not yet implemented)
groups:
  - name: bgp
    rules:
      - alert: CiliumBGPSessionDown
        expr: cilium_bgp_peer_state != 1
        for: 1m
        labels:
          severity: critical
```

## Cluster Rollout Order

For production safety, migrate clusters in order:

1. **dev** - Experimental, acceptable downtime
2. **integration** - Staging validation
3. **live** - Production (only after successful integration validation)

Each cluster requires its own UniFi neighbor configuration (different ASN).

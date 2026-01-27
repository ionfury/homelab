# UniFi BGP Configuration for Kubernetes

Configure BGP peering between UniFi Dream Machine and Kubernetes clusters running Cilium for LoadBalancer IP advertisement.

## Prerequisites

- UniFi Dream Machine Pro, Pro-Max, or SE
- UniFi OS **4.1.13** or newer (check via Settings > System > Console Info)
- SSH access to the UDM (Settings > System > SSH)
- Kubernetes clusters with Cilium BGP control plane enabled

## Architecture Overview

```
UniFi Router (ASN 64512)          Kubernetes Clusters
192.168.10.1                      ┌─────────────────────────┐
       │                          │ live (ASN 64513)        │
       │◄─── BGP eBGP ───────────►│ node41: 192.168.10.253  │
       │                          │ node42: 192.168.10.203  │
       │                          │ node43: 192.168.10.201  │
       │                          └─────────────────────────┘
       │                          ┌─────────────────────────┐
       │◄─── BGP eBGP ───────────►│ integration (ASN 64514) │
       │                          │ node46: 192.168.10.233  │
       │                          │ node47: 192.168.10.247  │
       │                          │ node48: 192.168.10.151  │
       │                          └─────────────────────────┘
       │                          ┌─────────────────────────┐
       │◄─── BGP eBGP ───────────►│ dev (ASN 64515)         │
       │                          │ node45: 192.168.10.252  │
       │                          └─────────────────────────┘
```

## Configuration Steps

### 1. Create FRR Configuration File

Create a file named `frr-bgp.conf` with the following content:

```frr
! UniFi BGP Configuration for Homelab Kubernetes
! Router: 192.168.10.1, ASN: 64512

frr version 8.4
frr defaults traditional
hostname udm-pro
log syslog informational

router bgp 64512
  bgp router-id 192.168.10.1
  no bgp ebgp-requires-policy
  no bgp default ipv4-unicast
  bgp graceful-restart
  maximum-paths 8

  ! Peer groups by cluster (different ASNs)
  neighbor LIVE peer-group
  neighbor LIVE remote-as 64513
  neighbor LIVE description Live cluster nodes
  neighbor LIVE soft-reconfiguration inbound
  neighbor LIVE timers 15 45
  neighbor LIVE timers connect 15

  neighbor INTEGRATION peer-group
  neighbor INTEGRATION remote-as 64514
  neighbor INTEGRATION description Integration cluster nodes
  neighbor INTEGRATION soft-reconfiguration inbound
  neighbor INTEGRATION timers 15 45
  neighbor INTEGRATION timers connect 15

  neighbor DEV peer-group
  neighbor DEV remote-as 64515
  neighbor DEV description Dev cluster nodes
  neighbor DEV soft-reconfiguration inbound
  neighbor DEV timers 15 45
  neighbor DEV timers connect 15

  ! Live cluster nodes
  neighbor 192.168.10.253 peer-group LIVE
  neighbor 192.168.10.253 description node41
  neighbor 192.168.10.203 peer-group LIVE
  neighbor 192.168.10.203 description node42
  neighbor 192.168.10.201 peer-group LIVE
  neighbor 192.168.10.201 description node43

  ! Integration cluster nodes
  neighbor 192.168.10.233 peer-group INTEGRATION
  neighbor 192.168.10.233 description node46
  neighbor 192.168.10.247 peer-group INTEGRATION
  neighbor 192.168.10.247 description node47
  neighbor 192.168.10.151 peer-group INTEGRATION
  neighbor 192.168.10.151 description node48

  ! Dev cluster node
  neighbor 192.168.10.252 peer-group DEV
  neighbor 192.168.10.252 description node45

  ! IPv4 Address Family
  address-family ipv4 unicast
    neighbor LIVE activate
    neighbor LIVE route-map K8S-LB-IN in
    neighbor LIVE route-map DENY-ALL out

    neighbor INTEGRATION activate
    neighbor INTEGRATION route-map K8S-LB-IN in
    neighbor INTEGRATION route-map DENY-ALL out

    neighbor DEV activate
    neighbor DEV route-map K8S-LB-IN in
    neighbor DEV route-map DENY-ALL out
  exit-address-family
!

! Prefix list for LoadBalancer IP ranges
! Live:        192.168.10.21-29
! Integration: 192.168.10.31-39
! Dev:         192.168.10.51-59
ip prefix-list K8S-LOADBALANCER-IPS seq 10 permit 192.168.10.16/28 le 32
ip prefix-list K8S-LOADBALANCER-IPS seq 20 permit 192.168.10.32/28 le 32
ip prefix-list K8S-LOADBALANCER-IPS seq 30 permit 192.168.10.48/28 le 32

! Accept only LoadBalancer IPs from K8s
route-map K8S-LB-IN permit 10
  match ip address prefix-list K8S-LOADBALANCER-IPS
!
route-map K8S-LB-IN deny 20
!

! Don't advertise anything to K8s nodes
route-map DENY-ALL deny 10
!

line vty
!
```

### 2. Upload Configuration via GUI

1. Navigate to: **Settings > Routing > BGP** (or Settings > Policy Table > Dynamic Routing)
2. Click **Upload**
3. Select your `frr-bgp.conf` file
4. The configuration will be applied immediately

### 3. Alternative: Configure via SSH

```bash
# SSH into UDM
ssh root@192.168.10.1

# Edit FRR configuration directly
vi /etc/frr/frr.conf
# (paste configuration from step 1)

# Restart FRR to apply changes
systemctl restart frr
```

## Verification

### On UniFi Router

```bash
# SSH into UDM
ssh root@192.168.10.1

# Enter FRR shell
vtysh

# Check BGP summary (all neighbors should show state Established)
show bgp summary

# Expected output:
# Neighbor        AS  MsgRcvd  MsgSent  State/PfxRcd
# 192.168.10.253  64513   100      100       2    <- live node41
# 192.168.10.203  64513   100      100       2    <- live node42
# ...

# Check received routes from a specific neighbor
show ip bgp neighbors 192.168.10.253 received-routes

# Check routing table for LoadBalancer IPs
show ip route 192.168.10.22
show ip route 192.168.10.32
show ip route 192.168.10.52
```

### On Kubernetes Nodes

```bash
# Check BGP peer status from Cilium
kubectl exec -n kube-system -it ds/cilium -- cilium bgp peers

# Check advertised routes
kubectl exec -n kube-system -it ds/cilium -- cilium bgp routes advertised ipv4 unicast
```

## Troubleshooting

### BGP Session Not Establishing

1. **Check firewall**: Ensure TCP port 179 is allowed between UDM and nodes
2. **Check ASN mismatch**: Verify Cilium is configured with the correct ASN for each cluster
3. **Check IP reachability**: Ping nodes from UDM to verify L3 connectivity

```bash
# On UDM, check if BGP port is reachable
nc -zv 192.168.10.253 179
```

### Routes Not Appearing in Routing Table

1. **Check `no bgp ebgp-requires-policy`**: Without this, FRR blocks all routes by default
2. **Check route-map**: Ensure the prefix-list covers your IP ranges
3. **If using ECMP**: Try `maximum-paths 1` if routes don't appear with multiple paths

```bash
# In vtysh, check for filtered routes
show ip bgp
show ip bgp neighbors 192.168.10.253 received-routes
```

### ECMP Not Working

ECMP reliability on UniFi is inconsistent. If traffic isn't load-balanced:

1. Verify `maximum-paths 8` is configured
2. Check kernel multipath settings: `sysctl net.ipv4.fib_multipath_hash_policy`
3. If still failing, fall back to `maximum-paths 1` for simple failover

## Rollback

To disable BGP and remove configuration:

```bash
# SSH into UDM
ssh root@192.168.10.1

# Remove BGP configuration
echo "" > /etc/frr/frr.conf

# Restart FRR
systemctl restart frr

# Verify BGP is disabled
vtysh -c "show bgp summary"
```

## References

- [UniFi BGP Documentation](https://help.ui.com/hc/en-us/articles/16271338193559-UniFi-Border-Gateway-Protocol-BGP)
- [FRRouting BGP Documentation](https://docs.frrouting.org/en/latest/bgp.html)
- [Cilium BGP Control Plane](https://docs.cilium.io/en/stable/network/bgp-control-plane/)

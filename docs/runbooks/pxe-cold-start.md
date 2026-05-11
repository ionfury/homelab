# PXE Cold Start — Break-Glass Runbook

## When to use

- Kubernetes cluster is down (no Deployment running)
- A bare-metal node needs PXE boot before the cluster is healthy
- booter Deployment is degraded and a node needs to boot now

## Pre-flight

1. Docker available on a host with direct access to the citadel VLAN (192.168.10.0/24)
2. Ports UDP 69, TCP 50084 free on the host
3. Read `booter_version` from `kubernetes/clusters/live/versions.env`
4. Read `talos_version` and `talos_pxe_schematic_id` from `kubernetes/clusters/live/versions.env`

## Image + tag

```
ghcr.io/siderolabs/booter:<booter_version>
```

Example: `ghcr.io/siderolabs/booter:v0.3.0`

## Run

```sh
docker run -d \
  --name booter \
  --network host \
  --cap-add NET_BIND_SERVICE \
  ghcr.io/siderolabs/booter:v0.3.0 \
  --talos-version=v1.13.0 \
  --schematic-id=613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245
```

Replace tag, `--talos-version`, and `--schematic-id` with values from `versions.env`.

## Verify

```sh
ss -ulnp | grep 69
ss -tlnp | grep 50084
curl -s http://localhost:50084/ipxe/talos | head -5
```

## Unifi next-server

In Unifi Network > Networks > citadel VLAN > DHCP > Advanced, set:

- **TFTP server (next-server)**: IP of the host running this container
- **Boot filename**: `ipxe.efi` (UEFI) or `undionly.kpxe` (BIOS)

In steady state, Unifi must point `next-server` to the Cilium LoadBalancer VIP (`booter_ip` in
`cluster-apps.env`) so that TFTP and HTTP boot asset requests reach the booter pod directly.
There is no proxyDHCP — Unifi owns DHCP and delivers the next-server address to PXE clients.

This is a manual step not captured in git.

## Decommission

Stop the container when the booter Deployment is fully ready:

```sh
kubectl --context live get deployment -n booter booter
docker stop booter
docker rm booter
```

Restore Unifi next-server to the Cilium LoadBalancer VIP (`booter_ip` in `cluster-apps.env`).

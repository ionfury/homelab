# PXE Cold Start — Break-Glass Runbook

## When to use

- Kubernetes cluster is down (no DaemonSet running)
- A bare-metal node needs PXE boot before the cluster is healthy
- booter DaemonSet is degraded and a node needs to boot now

## Pre-flight

1. Docker available on a host with direct access to the citadel VLAN (192.168.10.0/24)
2. Ports UDP 67, UDP 69, TCP 50084 free on the host
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
  --cap-add NET_RAW \
  ghcr.io/siderolabs/booter:v0.3.0 \
  --talos-version=v1.13.0 \
  --schematic-id=613e1592b2da41ae5e265e8789429f22e121aab91cb4deb6bc3c0b6262961245
```

Replace tag, `--talos-version`, and `--schematic-id` with values from `versions.env`.

## Verify

```sh
ss -ulnp | grep -E '67|69'
ss -tlnp | grep 50084
curl -s http://localhost:50084/ipxe/talos | head -5
```

## Unifi next-server

Set manually in Unifi Network > Networks > citadel VLAN > DHCP > Advanced:

- TFTP server: IP of the host running this container
- Boot filename: `ipxe.efi` (UEFI) or `undionly.kpxe` (BIOS)

This is a manual step not captured in git.

## Decommission

Stop the container when the booter DaemonSet is fully ready:

```sh
kubectl --context live get daemonset -n booter booter
docker stop booter
docker rm booter
```

Restore Unifi next-server to the Cilium LoadBalancer VIP (`booter_ip` in `cluster-apps.env`).

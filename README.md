# 🏠 ionfury-homelab

This repo documents my homelab infrastructure and GitOps configuration. I've recently rebuilt the whole stack on Talos, moving away from Rancher and Harvester. This setup is fully declarative, modular, and automated from PXE to production workloads.

---

<div align="center">

![heartbeat](https://img.shields.io/badge/dynamic/json?color=brightgreen&label=heartbeat&query=%24.status&url=https%3A%2F%2Fhealthchecks.io%2Fbadge%2Fb4308338-139b-4907-bee3-37c2da%2FiS3vfgkr-2.json&style=flat-square&logo=kubernetes&logoColor=white)&nbsp;&nbsp;
[![30D-Availability](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dapiserver_availability_30d&style=flat-square&label=Availability)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Power-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_power_usage&style=flat-square&label=Power)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;

</div>

---

<div align="center">

![Talos](https://img.shields.io/badge/Talos-1.10.4-blue?logo=kubernetes&style=for-the-badge)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.33.0-blue?logo=kubernetes&style=for-the-badge)
![Terragrunt](https://img.shields.io/badge/Terragrunt-0.81.5-blue?logo=terraform&style=for-the-badge)
![OpenTofu](https://img.shields.io/badge/OpenTofu-1.8.9-blue?logo=terraform&style=for-the-badge)

</div>

---

## Overview

This repository contains the infrastructure and GitOps configuration for my homelab. The current iteration is based on Talos Linux and Kubernetes, with everything deployed and reconciled through Flux. Provisioning is handled via PXE boot and Terragrunt modules for Talos-based clusters.

The entire stack is declarative, built to be reproducible, and optimized for hands-off operation. My goal here is to push the boundaries of what "infrastructure as code" actually means—starting from the BIOS and ending at an SLO dashboard.

---

## Table of Contents

- [Overview](#overview)
- [Directories](#directories)
- [Architecture](#architecture)
  - [Hardware](#hardware)
  - [Cloud Dependencies](#cloud-dependencies)
  - [Networking](#networking)
- [Bare Metal](#bare-metal)
- [Provisioning](#provisioning)
- [Deployment](#deployment)
- [License](#license)

---

## Directories

```
📁
├─ .github/          # GitHub workflows and actions
├─ .taskfiles/       # Reusable task automation with taskfile.dev
├─ docs/             # Runbooks and notes
├─ infrastructure/   # PXE + cluster provisioning via Terragrunt
├─ kubernetes/       # Flux-based GitOps manifests per cluster
├─ Taskfile.yaml     # Root taskfile entry
```

---

## Architecture

This setup has grown to support multiple environments and workload isolation via dedicated physical clusters. It's designed to withstand full cluster outages without taking down the rest of the network.

The network is segmented using VLANs, with one segment (`citadel`) allocated for Kubernetes infrastructure. PXE, DNS, and initial bootstrapping all happen within this VLAN.

<details>
  <summary>Click to see vlan diagram</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/home-network-firewall.png" align="center" alt="firewall"/>
</details>

---

### Hardware

| Device | CPU | RAM | Disks | Purpose |
|--------|-----|-----|-------|---------|
| Supermicro Nodes | Xeon E5 / D / 8C | 32-128GB | SSDs + HDDs | Talos cluster nodes |
| Pi 4 | ARM | 2-8GB | microSD | PXE, PXE DHCP, or test clusters |
| Unifi Aggregation | - | - | - | 10G switch |
| CyberPower UPS | - | - | - | Battery backup and monitoring |

<details>
  <summary>Front of rack</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/rack-1.jpg" align="center" alt="rack-front"/>
</details>

<details>
  <summary>Back of rack</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/rack-2.jpg" align="center" alt="rack-back"/>
</details>

---

### Cloud Dependencies

| Tool       | Purpose                     | Cost        |
|------------|-----------------------------|-------------|
| GitHub     | GitOps, CI/CD, tokens       | Free        |
| Cloudflare | DNS + public exposure       | ~$10/year   |
| AWS S3     | Terraform state, secrets    | ~$10/year   |
| Healthchecks.io | Heartbeats, Uptime    | Free        |

Total: ~$20/year

---


## Networking

Networking is handled via Unifi. The Talos cluster nodes reside in the `192.168.10.0/24` subnet, statically assigned by MAC. Talos is configured to use this subnet for the control plane VIP, service IPs, and ingress routing.

All cluster networks are Cilium-native and pods are assigned from separate /16 subnets per environment.

Ingress is exposed via NGINX with dedicated internal and external IPs. Blocky provides local DNS resolution and filtering.

---

## Bare Metal

Nodes are installed via PXE boot into Talos Linux. The PXE boot environment is managed declaratively through Terragrunt and includes MAC address mapping and static IP assignments.

Supermicro hardware is configured through IPMI with automation for NTP, naming, and password rotation documented in `docs/runbooks`.

---

## Provisioning

Talos clusters are provisioned via `terragrunt apply` from the `infrastructure/clusters` directory. Each cluster environment has its own set of HCL configurations that map hosts, IPs, and versions.

Clusters boot directly into Talos, join the cluster, and install Flux which begins reconciling workloads from the `kubernetes/` folder.

Example provisioning command:

```sh
cd infrastructure/clusters/live
terragrunt apply
```

---

## Deployment

Flux watches the cluster folder and automatically applies all manifests from the corresponding `kubernetes/clusters/<env>` directory.

Components are organized by namespace and include:

- Cert Manager
- Longhorn
- Monitoring Stack (Prometheus, Grafana, Loki, etc.)
- Ingress (NGINX)
- Cilium
- External Secrets
- Custom workloads

Changes are committed to Git and picked up automatically via GitOps.

---

## Network Policy

Network security is enforced using `NetworkPolicy` objects. Policies are structured as reusable components inside `.network-policies/`.

Each policy defines a `source/` and `destination/` and is bound to namespaces via Kustomize components and pod labels like `networking/allow-egress-to-postgres`.

A namespace can "opt-in" to default deny behavior by applying `allow-same-namespace`.

---

## Acknowledgements

Thanks to the Kubernetes@Home Discord community for all the shared patterns and tools. If you're building something similar, start there.

---

## License

See [LICENSE](./LICENSE)

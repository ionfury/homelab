<div align="center">

![Kubernetes](https://camo.githubusercontent.com/a05fb318da00bebbe807c966aa70007465738655edf9e1879f7d6ab68a55327f/68747470733a2f2f692e696d6775722e636f6d2f7031527a586a512e706e67)

### My homelab repository

#### _Built on Kubernetes, Harvester, and Rancher_

</div>

<br />

<div align="center">

![cluster](https://img.shields.io/badge/dynamic/json?color=brightgreen&label=cluster&query=%24.status&url=https%3A%2F%2Fhealthchecks.io%2Fbadge%2Fb4308338-139b-4907-bee3-37c2da%2FiS3vfgkr-2.json&style=for-the-badge&logo=kubernetes&logoColor=white)
[![Discord](https://img.shields.io/discord/673534664354430999?style=for-the-badge&label=discord&logo=discord&logoColor=white&color=blue)](https://discord.gg/k8s-at-home)
[![harvester](https://img.shields.io/badge/harvester-v1.2.1-brightgreen?style=for-the-badge&logo=openSUSE&logoColor=white&color=blue)](https://harvesterhci.io/)
[![rancher](https://img.shields.io/badge/rancher-v2.7.6-brightgreen?style=for-the-badge&logo=rancher&logoColor=white&color=blue)](https://www.rancher.com)
[![kubernetes](https://img.shields.io/badge/kubernetes-v1.26.8-brightgreen?style=for-the-badge&logo=kubernetes&logoColor=white&color=blue)](https://kubernetes.io/)

</div>

---

## Overview

This repository contains the infrastructure and deployment code for my HomeLab. The lab is built using [Harvester](https://harvesterhci.io/), [Rancher](https://www.rancher.com), and [Kubernetes](https://kubernetes.io/) and attempts to adhere to the principle of [Hyperconverged Infrastructure](https://www.suse.com/products/harvester/) (HCI).

Through this approach, compute, disk, and networking is unified into a single cluster.  These resources are then manged through gitops tooling:

- [**Terraform**](https://www.terraform.io/), for managing infrastructure.
- [**Flux**](https://fluxcd.io/), for managing services and software.

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

```sh
📁
├─📁 .taskfiles     # Commonly performed actions executable via taskfile.dev cli.
├─📁 .vscode        # Portable configuration for this repo.
├─📁 clusters       # Kubernetes clusters defined via gitops.
├─📁 docs           # Documentation, duh.
├─📁 manifests      # Realm of the .yaml files.
│ ├─📁 apps         # Kustomizations defining a single application to be deployed to a cluster.
│ ├─📁 components   # Re-usable kustomize components for use across applications.
│ └─📁 harvester    # Manifests used for harvester configuration.
└─📁 terraform      # Infrastructure provisioned via terraform.
  └─📁 .modules     # Re-usable terraform modules.
```

---

## Architecture

The ultimate aim of my homelab is to deploy the entirety of my services on kubernetes.  There are many paths to acheiving this goal, but I chose [Harvester](https://harvesterhci.io/) for two primary reasons:

- I wanted to try and use enterprise, rack mounted hardware

The homelab is designed to emulate the principal of [Hyperconverged Infrastructure](https://www.suse.com/products/harvester/), or HCI, on bare metal in my basement.

---

### Hardware

|Device|OS Disk|Data Disk|CPU|Memory|Purpose|
|------|-------|---------|---|------|-------|
|[Supermicro 1U](https://www.supermicro.com/en/products/system/1U/6018/SYS-6018U-TRTP_.cfm)|[2x 480Gb (RAID1)](https://www.amazon.com/gp/product/B07NRP3TVN)|[2x 480Gb (RAID1)](https://www.amazon.com/gp/product/B07NRP3TVN)|[E5-2630v4 2.20GHZ](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E5-2630+v4+%40+2.20GHz&id=2758&cpuCount=2)|8x 16GB DDR-4 (128GB)|HCI Node 1|
|[Supermicro 1U](https://www.supermicro.com/en/products/system/1U/6018/SYS-6018U-TRTP_.cfm)|[2x 1TB (RAID1)](https://www.amazon.com/dp/B078211KBB/ref=pe_386300_440135490_TE_simp_item_image)|[2x 20TB (RAID1)](https://www.amazon.com/Seagate-Exos-20TB-SATA-ST20000NM007D/dp/B09MWKXR2T)|[E5-2630v4 2.20GHZ](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E5-2630+v4+%40+2.20GHz&id=2758&cpuCount=2)|8x 16GB DDR-4 (128GB)|HCI Node 2|
|[Supermicro 4U](https://www.supermicro.com/products/system/4U/6048/SSG-6048R-E1CR36N.cfm)|[2x 1TB (RAID1)](https://www.amazon.com/dp/B078211KBB/ref=pe_386300_440135490_TE_simp_item_image)|[12x 4Tb (RAID50)](https://www.amazon.com/gp/product/B00A45JFJS/?th=1)|[E5-2630v4 2.20GHZ](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E5-2630+v4+%40+2.20GHz&id=2758&cpuCount=2)|8x 16GB DDR-4 (128GB)|HCI Node 3|
|[Unifi Aggregation](https://store.ui.com/us/en/pro/category/switching-aggregation/products/usw-aggregation)|-|-|-|-|10G SFP+ Switch|
|[CyberPower 1500VA UPS](https://www.cyberpowersystems.com/product/ups/smart-app-lcd/or1500lcdrt2u/)|-|-|-|-|Battery Backup|

---

### Cloud Dependencies

|tool|purpose|cost|
|----|-------|----|
|<img src="https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/f8baa56a7a29dec4603fa37651459234b2c693c9/assets/github-octocat.svg" width="24"> [github](https://www.github.com/)|Infrastructure as code management & CI/CD.| free |
|<img src="https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/f8baa56a7a29dec4603fa37651459234b2c693c9/assets/cloudflare.svg" width="24"> [cloudflare](https://www.cloudflare.com/)|DNS & Proxy management.| ~$10/yr |
|<img src="https://pbs.twimg.com/profile_images/1055543716201615365/geMDWaHV_400x400.jpg" width="24"> [healthchecks.io](https://healthchecks.io/) | Cluster heartbeats. | free |
|<img src="https://github.com/loganmarchione/homelab-svg-assets/raw/main/assets/amazonwebservices.svg" width="24"> [amazon](https://s3.console.aws.amazon.com/) | Backups, terraform state, and pilot light secrets. | ~$10/yr |
|||Total: ~$20/yr|

---

## Networking

Networking is provided by my [Unifi Dream Machine Pro](https://store.ui.com/collections/unifi-network-unifi-os-consoles/products/udm-pro) and is via [terraform](./terraform/network/).  The `citadel` vlan on `192.168.10.*` is dedicated to kubernetes nodes.

`192.168.10.2` is reserved as a gateway IP for the harvester cluster.  All other IPs are assigned via DHCP.  Initial local dns to access rancher is configured via terraform to make `rancher.tomnowak.work` available.

Downstream kubernetes clusteres can create services of type `Loadbalancer` via the harvester cloud provider, and are assigned an IP address in the same `citadel` vlan.  Internal cluster ingress is handled by a single ip requested by the internal [`nginx-ingress`](./clusters/homelab-1/network/ingress-nginx.yaml) controller.

Once an ip has been assigned, the [`cluster-vars.env`](./clusters/homelab-1/cluster-vars.env) is updated to reflect that ip, and [`blocky`](./clusters/homelab-1/network/blocky.yaml) consumes that to provide dns for the cluster to other networks.

Finally, the default vlan network is updated to provide the `blocky` loadbalancer ip for dns to all clients on the network, providing access to internal services and ad blocking.

<details>
  <summary>Click to see network security diagram</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/home-network-firewall.png" align="center" alt="firewall"/>
</details>

---

## Bare Metal

Currently running [Harvester v1.1.2](https://github.com/harvester/harvester/releases/tag/v1.1.2).

For provisioning a new harvester node, follow the installation instructions [here](https://docs.harvesterhci.io/v1.1/install/iso-install) via [USB](https://docs.harvesterhci.io/v1.1/install/usb-install).  The USB stick is sitting on top of the rack :).

Once the node has joined the cluster, manually log in to the web UI and configure the [host storage disk tags](https://docs.harvesterhci.io/v1.1/host/#multi-disk-management) through the [management interface](https://rancher.tomnowak.work/) with `hdd` and `ssd` tags.  Unfortunately the [terraform provider](https://github.com/harvester/terraform-provider-harvester) does not have functionality to facilitate host management.

---

## Provisioning

After the hosts are manually provisioned, [terraform](https://www.terraform.io/) is used to provision infrastructure via [terragrunt](https://terragrunt.gruntwork.io/).  Currently, all the terraform code is tightly coupled, but I hope to generalize it in the future.

The infrastructure consists roughly of three parts:

- [Network](./terraform/network/) configures my local unifi network infrastructure with a VNET and maps the ports allocated to current and future use for this homelab to be dedicated to those ports.
- [Harvester](.terraform/harvester/) configuration of harvester, such as storage and virtual networks.  You must download the harvester kubeconfig from [this](https://192.168.10.2/dashboard/harvester/c/local/support) link to run this module.
- [Rancher](./terraform/rancher-cluster/), which acts as the UI as the whole operation.  Currently provisioned manually as a single node due to harvester lacking [load balancing on vms](https://github.com/harvester/load-balancer-harvester/pull/13) or [built-in rancher integration](https://github.com/harvester/harvester/issues/2679).  Maybe in Harvester [`v1.2.0`](https://github.com/harvester/harvester/milestone/13).
- [Downstream Clusters](./terraform/clusters), which finally run the useful stuff.  The [cluster module](./terraform/.modules/rancher-harvester-cluster) provisions a cluster with [RKE2](https://docs.rke2.io/) through Rancher and bootstraps [flux](https://fluxcd.io/) onto the cluster, creating a deploy directory in [clusters/](./clusters/) which we can leverage to deploy workloads.

Simply run the following command to provision the infrastructure:

```sh
terragrunt run-all apply
```

---

## Deployment

[Flux](https://fluxcd.io/) handles deploying and managing workloads on the downstream clusters.  Flux is installed on the cluster and watches the directory in this repository in the previous step, syncing the cluster with any manifests found there.

---

## Acknowledgements

_Heavily_ inspired by the [Kubernetes @Home Discord](https://discord.gg/k8s-at-home) community.  Make sure to explore the [kubernetes @ home search](https://nanne.dev/k8s-at-home-search/)!

---

## License

See [LICENSE](./LICENSE)

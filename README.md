<div align="center">

![Kubernetes](https://camo.githubusercontent.com/a05fb318da00bebbe807c966aa70007465738655edf9e1879f7d6ab68a55327f/68747470733a2f2f692e696d6775722e636f6d2f7031527a586a512e706e67)

### My homelab repository

#### _Built on Kubernetes, Harvester, and Rancher_

</div>

<br />

<div align="center">

[![Discord](https://img.shields.io/discord/673534664354430999?style=for-the-badge&label=discord&logo=discord&logoColor=white)](https://discord.gg/k8s-at-home)
[![harvester](https://img.shields.io/badge/harvester-v1.1.1-brightgreen?style=for-the-badge&logo=openSUSE&logoColor=white)](https://https://harvesterhci.io/)
[![rancher](https://img.shields.io/badge/rancher-v2.7.1-brightgreen?style=for-the-badge&logo=rancher&logoColor=white)](https://www.rancher.com)
[![kubernetes](https://img.shields.io/badge/kubernetes-v1.24.3-brightgreen?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)

</div>

---

## Overview

This mono repository contains the infrastructure and deployment code for my HomeLab. The HomeLab is built on top of Harvester, Rancher, and Kubernetes using Terraform to manage infrastructure and Flux for deployment.

---

## Table of Contents

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
├─📁 clusters       # Kubernetes clusters defined as code.
├─📁 docs           # Documentation, duh.
├─📁 manifests      # Applications to be deployed into clusters.
└─📁 terraform      # Infrastructure provisioned via terraform .
```

---

## Architecture

The homelab is designed to emulate the principal of [Hyperconverged Infrastructure](https://www.suse.com/products/harvester/), or HCI, on bare metal in my basement.  The goal is to produce a near-complete cloud infrastructure locally, with minimal reliance on public cloud resources.

---

### Hardware

|Device|OS Disk|Data Disk|CPU|Memory|Purpose|
|------|-------|---------|---|------|-------|
|Dell R720xd|[2x 480Gb (RAID1)](https://www.amazon.com/gp/product/B07NRP3TVN)|[12x 4Tb (RAID50)](https://www.amazon.com/gp/product/B00A45JFJS/?th=1)|[2x E5-2620 @ 2.00GHz](https://www.cpubenchmark.net/cpu.php?cpu=intel+xeon+e5-2620+%40+2.00ghz&id=1214)|[16x 16GB DDR-3 (256GB)]()|HCI|
|[CyberPower 1500VA UPS](https://www.cyberpowersystems.com/product/ups/smart-app-lcd/or1500lcdrt2u/)|-|-|-|-|Battery Backup|
|[Unifi Dream Machine Pro]()|-|-|-|-|Network Controller|
|[Unifi Switch 24 PoE]()|-|-|-|-|Home Network Switch|

---

### Cloud Dependencies

|tool|purpose|cost|
|----|-------|----|
|<img src="https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/f8baa56a7a29dec4603fa37651459234b2c693c9/assets/github-octocat.svg" width="24"> [github](https://www.github.com/)|Infrastructure as code management & CI/CD.| free |
|<img src="https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/f8baa56a7a29dec4603fa37651459234b2c693c9/assets/cloudflare.svg" width="24"> [cloudflare](https://www.cloudflare.com/)|DNS & Proxy management.| free |
|<img src="https://github.com/loganmarchione/homelab-svg-assets/raw/main/assets/amazonwebservices.svg" width="24"> [amazon](https://s3.console.aws.amazon.com/) | Backups, terraform state, and pilot light secrets. | ~$5/mo |
|||Total: ~$60/yr|

---

## Networking

Networking is provided by my [Unifi Dream Machine Pro](https://store.ui.com/collections/unifi-network-unifi-os-consoles/products/udm-pro) and is currently configured manually.  Watch this space as I try and bring it [under management of terraform](https://registry.terraform.io/providers/paultyng/unifi/latest) in the future.

---

## Bare Metal

Currently running [Harvester v1.1.1](https://github.com/harvester/harvester/releases/tag/v1.1.1).

For provisioning a new harvester node, follow the installation instructions [here](https://docs.harvesterhci.io/v1.1/install/iso-install) via [USB](https://docs.harvesterhci.io/v1.1/install/usb-install).  The USB stick is sitting on top of the rack :). Retrieve the existing cluster token [like so](https://github.com/harvester/harvester/issues/2424).

Once the node has joined the cluster, manually log in to the web UI and configure the [host storage disk tags](https://docs.harvesterhci.io/v1.1/host/#multi-disk-management) through the [management interface](https://rancher.tomnowak.work/) with `hdd` and `ssd` tags.  Unfortunately the [terraform provider](https://github.com/harvester/terraform-provider-harvester) does not have functionality to facilitate host management.

---

## Provisioning

After the hosts are manually provisioned, [terraform](https://www.terraform.io/) is used to provision infrastructure via [terragrunt](https://terragrunt.gruntwork.io/).  Currently, all the terraform code is tightly coupled, but I hope to generalize it in the future.

The infrastructure consists roughly of three parts:

- [General](./terraform/general/) configuration of harvester, such as storage and virtual networks.  This is currently a mess and needs to be decomposed.
- [Rancher](./terraform/rancher-cluster/), which acts as the UI as the whole operation.  Currently provisioned manually as a single node due to harvester lacking [load balancing on vms](https://github.com/harvester/load-balancer-harvester/pull/13) or [built-in rancher integration](https://github.com/harvester/harvester/issues/2679).  Maybe in Harvester [`v1.2.0`](https://github.com/harvester/harvester/milestone/13).
- [Downstream Clusters](./terraform/cluster-01), which finally run the useful stuff.  The [cluster module](./terraform/.modules/rancher-rke2-cluster/) provisions a cluster with [RKE2](https://docs.rke2.io/) through Rancher and bootstraps [flux](https://fluxcd.io/) onto the cluster, creating a deploy directory in [clusters/](./clusters/) which we can leverage to deploy workloads.

> NOTE: You need to manually register the harvester cluster in rancher before creating downstream clusters. [link](https://docs.harvesterhci.io/v1.1/rancher/virtualization-management/)

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

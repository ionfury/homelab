<div align="center">

![Kubernetes](https://github.com/ionfury/homelab/blob/main/docs/images/k8s-logo.png)

### My homelab repository

#### _Built on Kubernetes, Harvester, and Rancher_

</div>

<div align="center">

[![Discord](https://img.shields.io/discord/673534664354430999?style=for-the-badge&label&logo=discord&logoColor=white&color=blue)](https://discord.gg/home-operations)&nbsp;&nbsp;
[![Kubernetes](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dkubernetes_version&style=for-the-badge&logo=kubernetes&logoColor=white&color=blue&label=%20)](https://docs.rke2.io/)


</div>

<div align="center">

![heartbeat](https://img.shields.io/badge/dynamic/json?color=brightgreen&label=heartbeat&query=%24.status&url=https%3A%2F%2Fhealthchecks.io%2Fbadge%2Fb4308338-139b-4907-bee3-37c2da%2FiS3vfgkr-2.json&style=flat-square&logo=kubernetes&logoColor=white)&nbsp;&nbsp;
[![Node-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_node_count&style=flat-square&label=Nodes)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Pod-Count](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_pod_count&style=flat-square&label=Pods)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![CPU-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_cpu_usage&style=flat-square&label=CPU)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;
[![Memory-Usage](https://img.shields.io/endpoint?url=https%3A%2F%2Fstats.tomnowak.work%2Fquery%3Fformat%3Dendpoint%26metric%3Dcluster_memory_usage&style=flat-square&label=Memory)](https://github.com/kashalls/kromgo/)&nbsp;&nbsp;

</div>

---

## Overview

This repository contains the infrastructure and deployment code for my Home Lab software and infrastructure.  The goal here is to experiment with, understand, and adopt GitOps and IaC best practices for Kubernetes.  Furthermore, this allows me to dabble all the way up the hardware stack to see where the rubber actually hits the road, so to speak.

The path I've chosen is through [Harvester](https://harvesterhci.io/), [Rancher](https://www.rancher.com), and [Kubernetes](https://kubernetes.io/) and attempts to adhere to the principle of [Hyperconverged Infrastructure](https://www.suse.com/products/harvester/) (HCI).  To do this I'm leveraging older rackmounted hardware.  It's not the most power efficent, but it's also not the worst.

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

My homelab architecture has gone through a number of revamps over the years but there has emerged a few key considerations:

- Enterprise gear is cooler than consumer stuff.  This rules out NUCs.
- Downtime is not fun when the wife is asking why the internet doesn't work.
- I enjoy overengineering things.

Through the confluence of the above factors I've arrived on the current iteration of my setup, which is split into two physically distinct parts: the `home` and the `lab`.  The `home` portion is a standard Unifi setup, managed out of my UDM Pro.  The `lab` portion is managed and described here, and is arranged such that any outage or maintenance of the lab will not impact the `home` portion.

The linkage between the two is done physically by a single 10Gb link, and by assigning the `client` vlan in the diagram below a primary dns server from the `lab` portion.  If, heaven forbid, the lab should suffer an outage, the `client` vlan is also given a second dns server to use.

<details>
  <summary>Click to see vlan diagram</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/home-network-firewall.png" align="center" alt="firewall"/>
</details>

---

### Hardware

#### Network

The network side of things is a straightforward Unifi setup.  The shelf up top houses some MoCA adapters for locations for convenience, and my modem tucked somewhere in the back.  My patch panels use a blue key for POE and gray for a non-POE jack.

<details>
  <summary>Click to see my network rack!</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/network-1.jpg" align="center" alt="firewall"/>
</details>

#### Lab

|Device|OS Disk|Data Disk|CPU|Memory|Purpose|
|------|-------|---------|---|------|-------|
|[Supermicro 1U](https://www.supermicro.com/en/products/system/1U/6018/SYS-6018U-TRTP_.cfm)|[2x 480Gb (RAID1)](https://www.amazon.com/gp/product/B07NRP3TVN)|[2x 480Gb (RAID1)](https://www.amazon.com/gp/product/B07NRP3TVN)|[E5-2630v4 2.20GHZ](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E5-2630+v4+%40+2.20GHz&id=2758&cpuCount=2)|8x 16GB DDR-4 (128GB)|HCI Node 1|
|[Supermicro 1U](https://www.supermicro.com/en/products/system/1U/6018/SYS-6018U-TRTP_.cfm)|[2x 1TB (RAID1)](https://www.amazon.com/dp/B078211KBB/ref=pe_386300_440135490_TE_simp_item_image)|[2x 20TB (RAID1)](https://www.amazon.com/Seagate-Exos-20TB-SATA-ST20000NM007D/dp/B09MWKXR2T)|[E5-2630v4 2.20GHZ](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E5-2630+v4+%40+2.20GHz&id=2758&cpuCount=2)|8x 16GB DDR-4 (128GB)|HCI Node 2|
|[Supermicro 4U](https://www.supermicro.com/products/system/4U/6048/SSG-6048R-E1CR36N.cfm)|[2x 1TB (RAID1)](https://www.amazon.com/dp/B078211KBB/ref=pe_386300_440135490_TE_simp_item_image)|[12x 4Tb (RAID50)](https://www.amazon.com/gp/product/B00A45JFJS/?th=1)|[E5-2630v4 2.20GHZ](https://www.cpubenchmark.net/cpu.php?cpu=Intel+Xeon+E5-2630+v4+%40+2.20GHz&id=2758&cpuCount=2)|8x 16GB DDR-4 (128GB)|HCI Node 3|
|[Unifi Aggregation](https://store.ui.com/us/en/pro/category/switching-aggregation/products/usw-aggregation)|-|-|-|-|10G SFP+ Switch|
|[CyberPower 1500VA UPS](https://www.cyberpowersystems.com/product/ups/smart-app-lcd/or1500lcdrt2u/)|-|-|-|-|Battery Backup|

<details>
  <summary>Click to see the front of my lab rack!</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/rack-1.jpg" align="center" alt="firewall"/>
</details>

<details>
  <summary>Click to see the back of my lab rack!</summary>
  <img src="https://raw.githubusercontent.com/ionfury/homelab/main/docs/images/rack-2.jpg" align="center" alt="firewall"/>
</details>

---

### Cloud Dependencies

I'm leveraging some cloud dependencies to really make things easier and dodge the harder questions.

|tool|purpose|cost|
|----|-------|----|
|<img src="https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/f8baa56a7a29dec4603fa37651459234b2c693c9/assets/github-octocat.svg" width="24"> [github](https://www.github.com/)|IaC, CI/CD, & SSO.| free |
|<img src="https://raw.githubusercontent.com/loganmarchione/homelab-svg-assets/f8baa56a7a29dec4603fa37651459234b2c693c9/assets/cloudflare.svg" width="24"> [cloudflare](https://www.cloudflare.com/)|DNS & Proxy management.| ~$10/yr |
|<img src="https://healthchecks.io/static/img/logo.png" width="24"> [healthchecks.io](https://healthchecks.io/) | Cluster heartbeats. | free |
|<img src="https://github.com/loganmarchione/homelab-svg-assets/raw/main/assets/amazonwebservices.svg" width="24"> [amazon](https://s3.console.aws.amazon.com/) | Backups, terraform state, secrets. | ~$10/yr |
|||Total: ~$20/yr|

---

## Networking

Networking

Networking is provided by my [Unifi Dream Machine Pro](https://store.ui.com/collections/unifi-network-unifi-os-consoles/products/udm-pro) and the lab portion is managed via [terraform](./terraform/network/).  The `citadel` vlan on `192.168.10.*` is allocated for the lab.

`192.168.10.2` is reserved as a gateway IP for the harvester cluster.  All other IPs are assigned via DHCP.  Initial local dns to access rancher is configured via terraform to make `rancher.tomnowak.work` available.

Downstream kubernetes clusteres can create services of type `Loadbalancer` via the harvester cloud provider, and are assigned an IP address in the same `citadel` vlan.  Internal cluster ingress is handled by a single ip requested by the internal [`nginx-ingress`](./clusters/homelab-1/network/ingress-nginx.yaml) controller.

Once an ip has been assigned, the [`cluster-vars.env`](./clusters/homelab-1/cluster-vars.env) is updated to reflect that ip, and [`blocky`](./clusters/homelab-1/network/blocky.yaml) consumes that to provide dns for the cluster to other networks.

Finally, the default vlan network is updated to provide the `blocky` loadbalancer ip for dns to all clients on the network, providing access to internal services and ad blocking.

---

## Bare Metal

Currently running [Harvester v1.1.2](https://github.com/harvester/harvester/releases/tag/v1.1.2).

For provisioning a new harvester node, follow the installation instructions [here](https://docs.harvesterhci.io/v1.1/install/iso-install) via [USB](https://docs.harvesterhci.io/v1.1/install/usb-install).  The USB stick is sitting on top of the rack :).

Once the node has joined the cluster, manually log in to the web UI and configure the [host storage disk tags](https://docs.harvesterhci.io/v1.1/host/#multi-disk-management) through the [management interface](https://rancher.tomnowak.work/) with `hdd` and `ssd` tags.  Unfortunately the [terraform provider](https://github.com/harvester/terraform-provider-harvester) does not have functionality to facilitate host management.

I'm running [seeder](https://docs.harvesterhci.io/v1.2/advanced/addons/seeder/) to manage basic BMC functionality on the nodes.  In the future I hope to manage provisioning for the cluster via this tool.

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

## Network Policy

Internal cluster policy is handled entirely via vanilla kubernetes `NetworkPolicy`.  The approach described here is to enable netpol to be implemented post deployment in a low-impact rollout.

  The policy is implemented at the cluster and namespace level.  Cluster network policy is described in the `clusters/<cluster>/.network-policies` directory.

Each subdirectory of `.network-policies` represents a specific policy.  These polices are generic to the point that they should be applicable to every namespace and bound to specific pods via labels.  Each policy should have a `source` and `destination` subdirectory, which contains the specific policy to be applied in a namespace. The policy is then included into namespaces as a kustomize component.  Policies are connected to pods via labels like `networking/<policy>`.

For a specific example, lets look at `.network-policies/allow-egress-to-postgres`.  Including the `source` subdirectory component in a namespace adds the policy, which matches the `networking/allow-egress-to-postgres: "true"` label.  Apps should include this label to use postgres.

The `allow-same-namespace` policy can be included in a namespace as an 'on' switch for netpol in a namespace.

---

## Acknowledgements

_Heavily_ inspired by the [Kubernetes @Home Discord](https://discord.gg/k8s-at-home) community.  Make sure to explore the [kubernetes @ home search](https://nanne.dev/k8s-at-home-search/)!

---

## License

See [LICENSE](./LICENSE)

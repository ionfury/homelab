locals {
  cluster_name     = "${basename(get_terragrunt_dir())}"
  cluster_endpoint = "${local.cluster_name}.k8s.${local.tld}"
  tld              = "tomnowak.work"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/clusters/common.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.36.0"
}

dependencies {
  paths = ["../dev"]
}

inputs = {
  cluster_name     = local.cluster_name
  cluster_endpoint = local.cluster_endpoint
  tld              = local.tld

  cluster_vip            = "192.168.10.70"
  cluster_node_subnet    = "192.168.10.0/24"
  cluster_pod_subnet     = "172.18.0.0/16"
  cluster_service_subnet = "172.19.0.0/16"

  cluster_env_vars = {
    cluster_id            = 1
    cluster_ip_pool_start = "192.168.10.71"
    cluster_ip_pool_stop  = "192.168.10.89"
    cluster_l2_interfaces = "[\"enp1s0f0\", \"ens1f0\"]"
    internal_domain       = local.tld
    internal_ingress_ip   = "192.168.10.72"
    external_domain       = local.tld
    external_ingress_ip   = "192.168.10.73"
  }

  prepare_longhorn     = true
  longhorn_mount_disk2 = true
  prepare_spegel       = true
  speedy_kernel_args   = true

  kubernetes_version = "1.32.1"
  talos_version      = "v1.9.3"
  flux_version       = "v2.4.0"
  prometheus_version = "17.0.2"
  cilium_version     = "1.17.0"
  cilium_helm_values = file("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml")

  timeout = "10m"

  machines = {
    node2 = {
      type    = "controlplane"
      install = {diskSelectors = []} # Default install disk set in raid controller.  Let jesus take the wheel.
      disks = [{
        device = "/dev/sdb"
        partitions = [{
          mountpoint = "/var/mnt/disk2"
        }]
      }]
      interfaces = [{
        hardwareAddr     = "0c:c4:7a:a4:f1:d2"
        addresses        = ["192.168.10.182"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.182/24"]
          dhcp_routeMetric = 100
        }]
      }]
    }
    node41 = {
      type    = "controlplane"
      install = {diskSelectors = ["type: 'ssd'"]}
      disks = [{
        device = "/dev/sdb"
        partitions = [{
          mountpoint = "/var/mnt/disk2"
        }]
      }]
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:bf:ee"
        addresses        = ["192.168.10.253"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.253/24"]
          dhcp_routeMetric = 100
        }]
      }]
    }
    node42 = {
      type        = "controlplane"
      install = {diskSelectors = ["type: 'ssd'"]}
      disks = [{
        device = "/dev/sdb"
        partitions = [{
          mountpoint = "/var/mnt/disk2"
        }]
      }]
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:bf:bc"
        addresses        = ["192.168.10.203"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.203/24"]
          dhcp_routeMetric = 100
        }]
      }]
    }
  }
}

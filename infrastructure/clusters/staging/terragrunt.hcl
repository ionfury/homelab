locals {
  cluster_name       = "${basename(get_terragrunt_dir())}"
  cluster_pod_subnet = "172.24.0.0/16"
  cluster_tld        = "tomnowak.work"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/clusters/common.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}"
}

inputs = {
  cluster_name           = local.cluster_name
  cluster_tld            = local.cluster_tld
  cluster_pod_subnet     = local.cluster_pod_subnet
  cluster_service_subnet = "172.25.0.0/16"
  cluster_vip            = "192.168.10.40"

  cluster_env_vars = {
    cluster_id            = 4
    cluster_ip_pool_start = "192.168.10.41"
    cluster_ip_pool_stop  = "192.168.10.49"
    cluster_l2_interfaces = "[\"ens1f0\"]"
    internal_domain       = local.cluster_tld
    internal_ingress_ip   = "192.168.10.42"
    external_domain       = local.cluster_tld
    external_ingress_ip   = "192.168.10.43"
  }

  cilium_version = "1.17.4"
  cilium_helm_values = templatefile("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml",
    {
      cluster_name       = local.cluster_name
      cluster_pod_subnet = local.cluster_pod_subnet
  })
  kubernetes_version = "1.33.0"
  talos_version      = "v1.10.4"
  flux_version       = "v2.6.1"
  prometheus_version = "17.0.2"

  machines = {
    node45 = {
      type    = "controlplane"
      install = { disk = "/dev/sda" }
      interfaces = [{
        hardwareAddr = "ac:1f:6b:2d:bf:ce"
        addresses    = [{ ip = "192.168.10.222" }]
      }]
    }
  }
}



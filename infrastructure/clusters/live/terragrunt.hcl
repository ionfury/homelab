locals {
  cluster_name = "${basename(get_terragrunt_dir())}"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/clusters/common.hcl"
  expose = true
}

include "inventory" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/inventory.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}"
}

dependencies {
  paths = ["../staging"]
}

inputs = {
  cluster_name = local.cluster_name
  cluster_tld  = include.common.locals.addresses.live.internal_tld

  cluster_node_subnet    = include.common.locals.addresses.live.node_subnet
  cluster_pod_subnet     = include.common.locals.addresses.live.pod_subnet
  cluster_service_subnet = include.common.locals.addresses.live.service_subnet
  cluster_vip            = include.common.locals.addresses.live.vip

  cluster_env_vars = [
    { "name" : "cluster_id", "value" : include.common.locals.addresses.live.id },
    { "name" : "cluster_ip_pool_start", "value" : include.common.locals.addresses.live.ip_pool_start },
    { "name" : "cluster_ip_pool_stop", "value" : include.common.locals.addresses.live.ip_pool_stop },
    { "name" : "internal_ingress_ip", "value" : include.common.locals.addresses.live.internal_ingress_ip },
    { "name" : "external_ingress_ip", "value" : include.common.locals.addresses.live.external_ingress_ip },
    { "name" : "internal_domain", "value" : include.common.locals.addresses.live.internal_tld },
    { "name" : "external_domain", "value" : include.common.locals.addresses.live.external_tld },
    { "name" : "cluster_l2_interfaces", "value" : "[\"ens1f0\"]" },
  ]

  cilium_helm_values = templatefile("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml", {
    cluster_name       = local.cluster_name
    cluster_pod_subnet = include.common.locals.addresses.live.pod_subnet
  })

  cilium_version     = include.common.locals.versions.cilium
  kubernetes_version = include.common.locals.versions.kubernetes
  talos_version      = include.common.locals.versions.talos
  flux_version       = include.common.locals.versions.flux
  prometheus_version = include.common.locals.versions.prometheus

  machines = {
    node41 = {
      type = "controlplane"
      install = {
        disk              = include.inventory.locals.hosts.node41.install_disk
        extensions        = include.common.locals.longhorn.machine_extensions
        extra_kernel_args = include.common.locals.kernel_args.fast
      }
      files = [
        include.common.locals.spegel.machine_files
      ]
      interfaces = [{
        hardwareAddr = include.inventory.locals.hosts.node41.endpoint.mac
        addresses    = [{ ip = include.inventory.locals.hosts.node41.endpoint.ip }]
      }]
    }
    node42 = {
      type = "controlplane"
      install = {
        disk              = include.inventory.locals.hosts.node42.install_disk
        extensions        = include.common.locals.longhorn.machine_extensions
        extra_kernel_args = include.common.locals.kernel_args.fast
      }
      files = [
        include.common.locals.spegel.machine_files
      ]
      interfaces = [{
        hardwareAddr = include.inventory.locals.hosts.node42.endpoint.mac
        addresses    = [{ ip = include.inventory.locals.hosts.node42.endpoint.ip }]
      }]
    }
    node43 = {
      type = "controlplane"
      install = {
        disk              = include.inventory.locals.hosts.node43.install_disk
        extensions        = include.common.locals.longhorn.machine_extensions
        extra_kernel_args = include.common.locals.kernel_args.fast
      }
      files = [
        include.common.locals.spegel.machine_files
      ]
      interfaces = [{
        hardwareAddr = include.inventory.locals.hosts.node43.endpoint.mac
        addresses    = [{ ip = include.inventory.locals.hosts.node43.endpoint.ip }]
      }]
    }
  }
}

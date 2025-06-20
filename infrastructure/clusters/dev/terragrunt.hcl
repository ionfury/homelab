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

inputs = {
  cluster_name = local.cluster_name
  cluster_tld  = include.common.locals.addresses.dev.internal_tld

  cluster_node_subnet    = include.common.locals.addresses.dev.node_subnet
  cluster_pod_subnet     = include.common.locals.addresses.dev.pod_subnet
  cluster_service_subnet = include.common.locals.addresses.dev.service_subnet
  cluster_vip            = include.common.locals.addresses.dev.vip

  cluster_env_vars = [
    { "name" : "cluster_id", "value" : include.common.locals.addresses.dev.id },
    { "name" : "cluster_ip_pool_start", "value" : include.common.locals.addresses.dev.ip_pool_start },
    { "name" : "cluster_ip_pool_stop", "value" : include.common.locals.addresses.dev.ip_pool_stop },
    { "name" : "internal_ingress_ip", "value" : include.common.locals.addresses.dev.internal_ingress_ip },
    { "name" : "external_ingress_ip", "value" : include.common.locals.addresses.dev.external_ingress_ip },
    { "name" : "internal_domain", "value" : include.common.locals.addresses.dev.internal_tld },
    { "name" : "external_domain", "value" : include.common.locals.addresses.dev.external_tld },
    { "name" : "cluster_l2_interfaces", "value" : "[\"end0\"]" },
  ]

  cilium_helm_values = templatefile("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml", {
    cluster_name       = local.cluster_name
    cluster_pod_subnet = include.common.locals.addresses.dev.pod_subnet
  })
  cilium_version     = include.common.locals.versions.cilium
  kubernetes_version = include.common.locals.versions.kubernetes
  talos_version      = include.common.locals.versions.talos
  flux_version       = include.common.locals.versions.flux
  prometheus_version = include.common.locals.versions.prometheus

  machines = {
    rpi1 = {
      type = "controlplane"
      install = {
        disk         = include.inventory.locals.hosts.rpi1.install_disk
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      interfaces = [{
        hardwareAddr = include.inventory.locals.hosts.rpi1.endpoint.mac
        addresses    = [{ ip = include.inventory.locals.hosts.rpi1.endpoint.ip }]
      }]
    }
    rpi2 = {
      type = "worker"
      install = {
        disk         = include.inventory.locals.hosts.rpi2.install_disk
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      interfaces = [{
        hardwareAddr = include.inventory.locals.hosts.rpi2.endpoint.mac
        addresses    = [{ ip = include.inventory.locals.hosts.rpi2.endpoint.ip }]
      }]
    }
  }
}

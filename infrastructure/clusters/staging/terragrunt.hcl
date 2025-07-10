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

include "networking" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/networking.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}"
}

inputs = {
  cluster_name = local.cluster_name
  cluster_tld  = include.networking.locals.domains.internal

  cluster_node_subnet    = include.networking.locals.addresses.staging.node_subnet
  cluster_pod_subnet     = include.networking.locals.addresses.staging.pod_subnet
  cluster_service_subnet = include.networking.locals.addresses.staging.service_subnet
  cluster_vip            = include.networking.locals.addresses.staging.vip

  cluster_env_vars = [
    { "name" : "cluster_id", "value" : include.networking.locals.addresses.staging.id },
    { "name" : "cluster_ip_pool_start", "value" : include.networking.locals.addresses.staging.ip_pool_start },
    { "name" : "cluster_ip_pool_stop", "value" : include.networking.locals.addresses.staging.ip_pool_stop },
    { "name" : "internal_ingress_ip", "value" : include.networking.locals.addresses.staging.internal_ingress_ip },
    { "name" : "external_ingress_ip", "value" : include.networking.locals.addresses.staging.external_ingress_ip },
    { "name" : "internal_domain", "value" : include.networking.locals.addresses.staging.internal_tld },
    { "name" : "external_domain", "value" : include.networking.locals.addresses.staging.external_tld },
    { "name" : "cluster_l2_interfaces", "value" : "[\"ens1f0\"]" },
  ]

  cilium_helm_values = templatefile("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml", {
    cluster_name          = local.cluster_name
    cluster_pod_subnet    = include.networking.locals.addresses.staging.pod_subnet
    default_replica_count = 1
  })

  cilium_version     = include.common.locals.versions.cilium
  kubernetes_version = include.common.locals.versions.kubernetes
  talos_version      = include.common.locals.versions.talos
  flux_version       = include.common.locals.versions.flux
  prometheus_version = include.common.locals.versions.prometheus

  machines = {
    node44 = {
      type = "controlplane"
      install = {
        disk_filters      = { model = include.inventory.locals.hosts.node44.os_disk }
        extensions        = include.common.locals.longhorn.machine_extensions
        extra_kernel_args = include.common.locals.kernel_args.fast
      }
      disks = include.inventory.locals.hosts.node44.disks
      files = [
        include.common.locals.spegel.machine_files
      ]
      labels = [
        include.common.locals.longhorn.labels.create_default_disk
      ]
      annotations = [{
        key   = "node.longhorn.io/default-disks-config"
        value = "'${jsonencode([{ "name" : "disk1", "path" : "/var/mnt/disk1", "storageReserved" : 0, "allowScheduling" : true, "tags" : ["fast", "slow"] }, { "name" : "disk2", "path" : "/var/mnt/disk2", "storageReserved" : 0, "allowScheduling" : true, "tags" : ["fast", "slow"] }])}'"
      }]
      kubelet_extraMounts = [
      #  include.common.locals.longhorn.kubelet_extraMounts.rootDisk,
        include.common.locals.longhorn.kubelet_extraMounts.disk1,
        include.common.locals.longhorn.kubelet_extraMounts.disk2,
      ]
      interfaces = [{
        hardwareAddr = include.inventory.locals.hosts.node44.endpoint.mac
        addresses    = [{ ip = include.inventory.locals.hosts.node44.endpoint.ip }]
      }]
    }
  }

  external_secrets = {
    id_store     = "/homelab/infrastructure/accounts/staging/external-secrets/id"
    secret_store = "/homelab/infrastructure/accounts/staging/external-secrets/secret"
  }
}

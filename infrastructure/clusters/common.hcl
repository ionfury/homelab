locals {
  # renovate: datasource=github-tags depName=ionfury/homelab-modules
  version         = "v0.75.0"
  base_source_url = "git::https://github.com/ionfury/homelab-modules.git//modules/cluster?ref=${local.version}"

  networking_vars = read_terragrunt_config(find_in_parent_folders("networking.hcl"))
  inventory_vars  = read_terragrunt_config(find_in_parent_folders("inventory.hcl"))

  cluster_name = "${basename(get_terragrunt_dir())}"
  internal_tld = "internal.${local.cluster_name}.${local.networking_vars.locals.domains.internal}"
  external_tld = "external.${local.cluster_name}.${local.networking_vars.locals.domains.external}"

  machines = {
    for name, host in local.inventory_vars.locals.hosts :
    name => merge(
      host,
      {
        install = merge(
          lookup(host, "install", {}),
          {
            extensions        = local.longhorn.machine_extensions
            extra_kernel_args = local.kernel_args.fast
          }
        )
        labels = concat(lookup(host, "labels", []), [local.longhorn.labels.create_default_disk])
        kubelet_extraMounts = concat(
          [local.longhorn.kubelet_extraMounts.rootDisk],
          [
            for d in lookup(host, "disks", []) : {
              destination = d.mountpoint
              type        = "bind"
              source      = d.mountpoint
              options     = ["bind", "rshared", "rw"]
            }
          ]
        )
        files = concat(lookup(host, "files", []), [local.spegel.machine_files])
        annotations = concat(
          lookup(host, "annotations", []),
          (tostring(lookup(lookup(lookup(host, "install", {}), "data", {}), "enabled", false)) == "true" || length(lookup(host, "disks", [])) > 0) ? [
            {
              key = "node.longhorn.io/default-disks-config"
              value = "'${jsonencode([
                for d in concat(
                  (tostring(lookup(lookup(lookup(host, "install", {}), "data", {}), "enabled", false)) == "true" ? [{
                    mountpoint = "/var/lib/longhorn"
                    tags       = lookup(lookup(lookup(host, "install", {}), "data", {}), "tags", [])
                  }] : []),
                  lookup(host, "disks", [])
                ) : {
                  name             = basename(d.mountpoint)
                  path             = d.mountpoint
                  storageReserved  = 0
                  allowScheduling  = true
                  tags             = lookup(d, "tags", [])
                }
              ])}'"
            }
          ] : []
        )
      }
    )
    if host.cluster == local.cluster_name
  }

  spegel = {
    machine_files = {
      path        = "/etc/cri/conf.d/20-customization.part"
      op          = "create"
      permissions = "0o666"
      content     = <<-EOT
          [plugins."io.containerd.cri.v1.images"]
            discard_unpacked_layers = false
        EOT
    }
  }

  kernel_args = {
    fast = [
      "apparmor=0",
      "init_on_alloc=0",
      "init_on_free=0",
      "mitigations=off",
      "security=none"
    ]
  }

  longhorn = {
    machine_extensions = [
      "iscsi-tools",
      "util-linux-tools"
    ]

    labels = {
      create_default_disk = {
        key   = "node.longhorn.io/create-default-disk"
        value = "config"
      }
    }

    kubelet_extraMounts = {
      rootDisk = {
        destination = "/var/lib/longhorn"
        type        = "bind"
        source      = "/var/lib/longhorn"
        options = [
          "bind",
          "rshared",
          "rw",
        ]
      }
      disk1 = {
        destination = "/var/mnt/disk1"
        type        = "bind"
        source      = "/var/mnt/disk1"
        options = [
          "bind",
          "rshared",
          "rw",
        ]
      }
      disk2 = {
        destination = "/var/mnt/disk2"
        type        = "bind"
        source      = "/var/mnt/disk2"
        options = [
          "bind",
          "rshared",
          "rw",
        ]
      }
    }
  }
}

inputs = {
  cluster_name = local.cluster_name
  cluster_tld  = local.internal_tld

  cluster_node_subnet    = local.networking_vars.locals.addresses[local.cluster_name].node_subnet
  cluster_pod_subnet     = local.networking_vars.locals.addresses[local.cluster_name].pod_subnet
  cluster_service_subnet = local.networking_vars.locals.addresses[local.cluster_name].service_subnet
  cluster_vip            = local.networking_vars.locals.addresses[local.cluster_name].vip

  machines = local.machines

  cluster_env_vars = [
    { "name" : "cluster_id", "value" : local.networking_vars.locals.addresses[local.cluster_name].id },
    { "name" : "cluster_ip_pool_start", "value" : local.networking_vars.locals.addresses[local.cluster_name].ip_pool_start },
    { "name" : "cluster_ip_pool_stop", "value" : local.networking_vars.locals.addresses[local.cluster_name].ip_pool_stop },
    { "name" : "internal_ingress_ip", "value" : local.networking_vars.locals.addresses[local.cluster_name].internal_ingress_ip },
    { "name" : "external_ingress_ip", "value" : local.networking_vars.locals.addresses[local.cluster_name].external_ingress_ip },
    { "name" : "internal_domain", "value" : local.internal_tld },
    { "name" : "external_domain", "value" : local.external_tld },
    { "name" : "cluster_l2_interfaces", "value" : jsonencode(distinct(flatten([for m in values(local.machines) : [for iface in lookup(m, "interfaces", []) : iface.id]]))) },
  ]

  cilium_helm_values = templatefile("${get_terragrunt_dir()}/../../../kubernetes/manifests/helm-release/cilium/values.yaml", {
    cluster_name          = local.cluster_name
    cluster_pod_subnet    = local.networking_vars.locals.addresses[local.cluster_name].pod_subnet
    internal_domain       = local.internal_tld
    default_replica_count = 1
  })


  talos_config_path      = "~/.talos"
  kubernetes_config_path = "~/.kube"
  nameservers            = ["192.168.10.1"]
  timeservers            = ["0.pool.ntp.org", "1.pool.ntp.org"]
  ssm_output_path        = "/homelab/infrastructure/clusters"

  cluster_etcd_extraArgs = [
    { name = "listen-metrics-urls", value = "http://0.0.0.0:2381" },
  ]
  cluster_scheduler_extraArgs = [
    { name = "bind-address", value = "0.0.0.0" }
  ]
  cluster_controllerManager_extraArgs = [
    { name = "bind-address", value = "0.0.0.0" }
  ]
  cluster_on_destroy = {
    graceful = false
    reboot   = true
    reset    = true
  }
}

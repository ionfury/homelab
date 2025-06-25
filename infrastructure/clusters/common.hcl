locals {
  # renovate: datasource=github-tags depName=ionfury/homelab-modules
  version         = "v0.70.0"
  base_source_url = "git::https://github.com/ionfury/homelab-modules.git//modules/cluster?ref=${local.version}"

  domains = {
    internal = "tomnowak.work"
    external = "tomnowak.work"
  }

  versions = {
    kubernetes = "1.33.0"
    talos      = "v1.10.4"
    flux       = "v2.6.1"
    prometheus = "17.0.2"
    cilium     = "1.17.4"
  }

  citadel_subnet = "192.168.10.0/24"

  addresses = {

    live = {
      id           = 1
      internal_tld = local.domains.internal
      external_tld = local.domains.external

      node_subnet         = local.citadel_subnet
      pod_subnet          = "172.18.0.0/16"
      service_subnet      = "172.19.0.0/16"
      vip                 = "192.168.10.20"
      ip_pool_start       = "192.168.10.21"
      internal_ingress_ip = "192.168.10.22"
      external_ingress_ip = "192.168.10.23"
      ip_pool_stop        = "192.168.10.29"
    }
    integration = {
      id           = 2
      internal_tld = local.domains.internal
      external_tld = local.domains.external

      node_subnet         = local.citadel_subnet
      pod_subnet          = "172.20.0.0/16"
      service_subnet      = "172.21.0.0/16"
      vip                 = "192.168.10.30"
      ip_pool_start       = "192.168.10.31"
      internal_ingress_ip = "192.168.10.32"
      external_ingress_ip = "192.168.10.33"
      ip_pool_stop        = "192.168.10.39"
    }
    staging = {
      id           = 3
      internal_tld = local.domains.internal
      external_tld = local.domains.external

      node_subnet         = local.citadel_subnet
      pod_subnet          = "172.22.0.0/16"
      service_subnet      = "172.23.0.0/16"
      vip                 = "192.168.10.40"
      ip_pool_start       = "192.168.10.41"
      internal_ingress_ip = "192.168.10.42"
      external_ingress_ip = "192.168.10.43"
      ip_pool_stop        = "192.168.10.49"
    }
    dev = {
      id           = 4
      internal_tld = local.domains.internal
      external_tld = local.domains.external

      node_subnet         = local.citadel_subnet
      pod_subnet          = "172.24.0.0/16"
      service_subnet      = "172.25.0.0/16"
      vip                 = "192.168.10.50"
      ip_pool_start       = "192.168.10.51"
      internal_ingress_ip = "192.168.10.52"
      external_ingress_ip = "192.168.10.53"
      ip_pool_stop        = "192.168.10.59"
    }
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

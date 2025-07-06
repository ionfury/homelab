locals {
  # renovate: datasource=github-tags depName=ionfury/homelab-modules
  version         = "v0.72.0"
  base_source_url = "git::https://github.com/ionfury/homelab-modules.git//modules/cluster?ref=${local.version}"

  versions = {
    kubernetes = "1.33.0"
    talos      = "v1.10.4"
    flux       = "v2.6.1"
    prometheus = "17.0.2"
    cilium     = "1.17.4"
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

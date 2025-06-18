locals {
  version         = "v0.67.0"
  base_source_url = "git::https://github.com/ionfury/homelab-modules.git//modules/cluster?ref=${local.version}"

  spegel_machine_files = {
    path        = "/etc/cri/conf.d/20-customization.part"
    op          = "create"
    permissions = "0o666"
    content     = <<-EOT
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
      EOT
  }

  fast_kernel_args = [
    "apparmor=0",
    "init_on_alloc=0",
    "init_on_free=0",
    "mitigations=off",
    "security=none"
  ]

  longhorn_machine_extensions = [
    "iscsi-tools",
    "util-linux-tools"
  ]

  longhorn_rootdisk_machine_kubelet_extraMount = {
    destination = "/var/lib/longhorn"
    type        = "bind"
    source      = "/var/lib/longhorn"
    options = [
      "bind",
      "rshared",
      "rw",
    ]
  }

  longhorn_disk2_machine_kubelet_extraMount = {
    destination = "/var/mnt/disk2"
    type        = "bind"
    source      = "/var/mnt/disk2"
    options = [
      "bind",
      "rshared",
      "rw",
    ]
  }

  longhorn_disk3_machine_kubelet_extraMount = {
    destination = "/var/mnt/disk3"
    type        = "bind"
    source      = "/var/mnt/disk3"
    options = [
      "bind",
      "rshared",
      "rw",
    ]
  }
}

inputs = {
  talos_config_path      = "~/.talos"
  kubernetes_config_path = "~/.kube"
  nameservers            = ["192.168.10.1"]
  timeservers            = ["0.pool.ntp.org", "1.pool.ntp.org"]
  cluster_node_subnet    = "192.168.10.0/24"
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

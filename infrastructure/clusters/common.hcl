locals {
  version         = "v0.67.0"
  base_source_url = "git::https://github.com/ionfury/homelab-modules.git//modules/cluster?ref=${local.version}"

}

inputs = {
  talos_config_path      = "~/.talos"
  kubernetes_config_path = "~/.kube"
  nameservers            = ["192.168.10.1"]
  timeservers            = ["0.pool.ntp.org", "1.pool.ntp.org"]
  cluster_node_subnet    = "192.168.10.0/24"
  ssm_output_path        = "/homelab/infrastructure/clusters"

  cluster_etcd_extraArgs = [
    { name = "listen-metrics-urls", value = "http:/0.0.0.0:2381" },
  ]
  cluster_scheduler_extaArgs = [
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

locals {
  base_source_url = "git::git@github.com:ionfury/homelab-modules.git//modules/cluster"
}

inputs = {
  talos_config_path   = "~/.talos"
  kube_config_path    = "~/.kube"
  nameservers         = ["192.168.10.1"]
  timeservers         = ["0.pool.ntp.org", "1.pool.ntp.org"]
  cluster_node_subnet = "192.168.10.0/24"
  timeout             = "10m"
}

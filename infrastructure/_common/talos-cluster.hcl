locals {
  base_source_url = "git::git@github.com:ionfury/homelab-modules.git//modules/talos-cluster"
}

inputs = {
  talos_config_path           = "~/.talos"
  kubernetes_config_path      = "~/.kube"
  machine_network_nameservers = ["192.168.10.1"]
  machine_time_servers        = ["0.pool.ntp.org", "1.pool.ntp.org"]
  cluster_node_subnet         = "192.168.10.0/24"
}

locals {
  master_email = "ionfury@gmail.com"
  default_network_tld = "tomnowak.work"
  default_network_name = "citadel"
  default_network_vlan = 10
  default_network_cidr = "192.168.${local.default_network_vlan}.0/24"
  harvester_node_count = 1
}

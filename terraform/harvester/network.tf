resource "harvester_clusternetwork" "this" {
  name        = var.default_network_name
  description = "Default net for harvester management cluster."
}

resource "harvester_network" "this" {
  cluster_network_name = harvester_clusternetwork.this.name
  config = jsonencode(
    {
      bridge      = "${var.default_network_name}-br"
      cniVersion  = "0.3.1"
      ipam        = {}
      name        = "${var.default_network_name}"
      promiscMode = true
      type        = "bridge"
      vlan        = var.default_network_vlan
    }
  )
  name          = var.default_network_name
  namespace     = "default"
  route_cidr    = var.default_network_cidr
  route_gateway = cidrhost(var.default_network_cidr, 1)
  route_mode    = "manual"
  tags          = {}
  vlan_id       = var.default_network_vlan
}

resource "harvester_vlanconfig" "this" {
  cluster_network_name = harvester_clusternetwork.this.name
  description          = "Default uplink for harvester network."
  name                 = var.default_network_name
  tags                 = {}

  # If we add additional nodes we will need specific configs for nodes.
  #  node_selector = {
  #    "kubernetes.io/hostname" : "harvester0"
  #  }

  uplink {
    bond_miimon = 0
    mtu         = 1500
    bond_mode   = "balance-tlb"
    nics = [
      "eno2",
      "eno3"
    ]
  }
}

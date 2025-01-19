resource "harvester_clusternetwork" "this" {
  name        = var.harvester.network_name
  description = "Default net for harvester management cluster."
}

resource "harvester_network" "this" {
  cluster_network_name = harvester_clusternetwork.this.name
  config = jsonencode(
    {
      bridge      = "${var.harvester.network_name}-br"
      cniVersion  = "0.3.1"
      ipam        = {}
      name        = "${var.harvester.network_name}"
      promiscMode = true
      type        = "bridge"
      vlan        = var.networks[var.harvester.network_name].vlan
    }
  )
  name          = var.harvester.network_name
  namespace     = "default"
  route_cidr    = var.networks[var.harvester.network_name].cidr
  route_gateway = cidrhost(var.networks[var.harvester.network_name].cidr, 1)
  route_mode    = "manual"
  tags          = {}
  vlan_id       = var.networks[var.harvester.network_name].vlan
}

resource "harvester_vlanconfig" "inventory" {
  for_each = var.harvester.inventory

  cluster_network_name = harvester_clusternetwork.this.name
  description          = "Uplink for ${each.key} to vlan ${harvester_clusternetwork.this.name}."
  name                 = "${each.key}-${harvester_clusternetwork.this.name}"
  tags                 = {}

  node_selector = {
    "kubernetes.io/hostname" : "${each.key}"
  }

  uplink {
    bond_miimon = -1
    mtu         = 1500
    bond_mode   = "balance-tlb"
    nics        = each.value.uplinks
  }
}

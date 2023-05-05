resource "harvester_network" "kubernetes" {
  cluster_network_name = "kubernetes"
  config = jsonencode(
    {
      bridge      = "kubernetes-br"
      cniVersion  = "0.3.1"
      ipam        = {}
      name        = "kubernetes"
      promiscMode = true
      type        = "bridge"
      vlan        = 5
    }
  )
  name          = "kubernetes"
  namespace     = "default"
  route_cidr    = "192.168.5.1/24"
  route_gateway = "192.168.5.1"
  route_mode    = "manual"
  tags          = {}
  vlan_id       = 5
}

resource "harvester_network" "harvester" {
  cluster_network_name = "rancher"
  config = jsonencode(
    {
      bridge      = "rancher-br"
      cniVersion  = "0.3.1"
      ipam        = {}
      name        = "harvester"
      promiscMode = true
      type        = "bridge"
      vlan        = 4
    }
  )
  name          = "harvester"
  namespace     = "default"
  route_cidr    = "192.168.4.1/24"
  route_gateway = "192.168.4.1"
  route_mode    = "manual"
  tags          = {}
  vlan_id       = 4
}

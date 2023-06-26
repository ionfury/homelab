resource "harvester_vlanconfig" "harvester0-uplink" {
  cluster_network_name = "kubernetes"
  name                 = "harvester0-uplink"
  node_selector = {
    "kubernetes.io/hostname" = "harvester0"
  }
  tags = {}

  uplink {
    mtu = 0
    nics = [
      "eno3",
    ]
  }
}

resource "harvester_vlanconfig" "harvester1-uplink" {
  cluster_network_name = "kubernetes"
  name                 = "harvester1-uplink"
  node_selector = {
    "kubernetes.io/hostname" = "harvester1"
  }
  tags = {}

  uplink {
    mtu = 0
    nics = [
      "eno1"
    ]
  }
}

resource "harvester_vlanconfig" "harvester" {
  cluster_network_name = "harvester"
  description          = "Dedicated network for harvester."
  name                 = "harvester"
  tags                 = {}

  uplink {
    bond_miimon = 0
    mtu         = 0
    nics = [
      "eno2"
    ]
  }
}


resource "unifi_network" "kubernetes" {
  name        = "kubernetes"
  purpose     = "corporate"
  site        = "default"
  domain_name = "k8s.local"
  vlan_id     = 5
  subnet      = "192.168.5.0/24"

  dhcp_dns           = []
  dhcp_enabled       = true
  dhcp_relay_enabled = false
  dhcp_start         = "192.168.5.6"
  dhcp_stop          = "192.168.5.126"

  dhcp_v6_dns      = []
  dhcp_v6_dns_auto = false
  dhcp_v6_enabled  = false
  dhcp_v6_lease    = 0

  dhcpd_boot_enabled = false

  igmp_snooping              = false
  ipv6_ra_enable             = false
  ipv6_ra_preferred_lifetime = 0
  ipv6_ra_valid_lifetime     = 0
  multicast_dns              = true

  # wan_dhcp_v6_pd_size = 0
  # wan_dns             = []
  # wan_prefixlen       = 0
}

resource "unifi_network" "harvester" {
  name        = "harvester"
  purpose     = "corporate"
  site        = "default"
  domain_name = "harvester.local"
  vlan_id     = 4
  subnet      = "192.168.4.0/24"

  dhcp_dns           = []
  dhcp_enabled       = true
  dhcp_relay_enabled = false
  dhcp_start         = "192.168.4.6"
  dhcp_stop          = "192.168.4.254"

  dhcp_v6_dns      = []
  dhcp_v6_dns_auto = false
  dhcp_v6_enabled  = false
  dhcp_v6_lease    = 0

  dhcpd_boot_enabled = false

  igmp_snooping              = false
  ipv6_ra_enable             = false
  ipv6_ra_preferred_lifetime = 0
  ipv6_ra_valid_lifetime     = 0
  multicast_dns              = true

  # wan_dhcp_v6_pd_size = 0
  # wan_dns             = []
  # wan_prefixlen       = 0
}

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

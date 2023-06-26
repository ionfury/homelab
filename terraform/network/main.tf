resource "unifi_network" "this" {
  name        = var.default_network_name
  purpose     = "corporate"
  site        = "default"
  domain_name = "${var.default_network_name}.${var.default_network_tld}"
  vlan_id     = var.default_network_vlan
  subnet      = var.default_network_cidr

  dhcp_dns           = []
  dhcp_enabled       = true
  dhcp_relay_enabled = false
  dhcp_start         = cidrhost(var.default_network_cidr, 10)
  dhcp_stop          = cidrhost(var.default_network_cidr, 254)
  dhcpd_boot_enabled = false

  dhcp_v6_dns      = []
  dhcp_v6_dns_auto = false
  dhcp_v6_enabled  = false
  dhcp_v6_lease    = 0

  igmp_snooping              = true
  ipv6_ra_enable             = false
  ipv6_ra_preferred_lifetime = 0
  ipv6_ra_valid_lifetime     = 0
  multicast_dns              = true
}


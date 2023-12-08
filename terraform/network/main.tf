resource "unifi_network" "networks" {
  for_each = var.networks

  name        = each.value.name
  purpose     = "corporate"
  site        = each.value.site
  domain_name = "${each.value.name}.${var.tld}"
  vlan_id     = each.value.vlan
  subnet      = each.value.cidr

  dhcp_dns           = []
  dhcp_enabled       = true
  dhcp_relay_enabled = false
  dhcp_start         = cidrhost(each.value.cidr, each.value.dhcp_start)
  dhcp_stop          = cidrhost(each.value.cidr, each.value.dhcp_stop)
  dhcpd_boot_enabled = false

  dhcp_v6_dns      = []
  dhcp_v6_dns_auto = false
  dhcp_v6_enabled  = false
  dhcp_v6_lease    = 86400

  igmp_snooping              = false
  ipv6_ra_enable             = false
  ipv6_ra_preferred_lifetime = 0
  ipv6_ra_valid_lifetime     = 0
  multicast_dns              = false
}

resource "unifi_port_profile" "profiles" {
  for_each = var.networks

  name     = each.value.name
  poe_mode = "auto"

  native_networkconf_id = unifi_network.networks[each.value.name].id
}

resource "unifi_device" "devices" {
  for_each = var.unifi.devices

  mac  = each.value.mac
  name = each.value.name

  dynamic "port_override" {
    for_each = each.value.port_overrides

    content {
      number          = port_override.value.port
      name            = "${port_override.value.network}-${port_override.value.port}"
      port_profile_id = unifi_port_profile.profiles[port_override.value.network].id
    }
  }
}

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

  # https://github.com/paultyng/terraform-provider-unifi/issues/287
  dhcp_v6_dns      = []
  dhcp_v6_dns_auto = false
  dhcp_v6_enabled  = false
  dhcp_v6_lease    = 86400
  dhcp_v6_start    = "::2"
  dhcp_v6_stop     = "::7d1"
  ipv6_pd_start    = "::2"
  ipv6_pd_stop     = "::7d1"

  igmp_snooping          = false
  ipv6_ra_enable         = false
  ipv6_ra_priority       = "high"
  ipv6_ra_valid_lifetime = 0
  multicast_dns          = false
}

resource "unifi_port_profile" "profiles" {
  for_each = var.networks

  name     = each.value.name
  poe_mode = "auto"

  # https://github.com/paultyng/terraform-provider-unifi/issues/287
  # Reguired if you ever touch the profile in the UI
  egress_rate_limit_kbps_enabled = false
  egress_rate_limit_kbps         = 100
  stormctrl_bcast_enabled        = false
  stormctrl_bcast_rate           = 100
  stormctrl_mcast_rate           = 100
  stormctrl_ucast_rate           = 100


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

resource "unifi_user" "inventory" {
  for_each = var.harvester.inventory

  name       = each.value.ipmi.host
  mac        = each.value.ipmi.mac
  fixed_ip   = each.value.ipmi.ip
  network_id = unifi_network.networks[var.harvester.network_name].id
}

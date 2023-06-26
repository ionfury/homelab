resource "unifi_port_profile" "this" {
  name = "${var.default_network_name}-custom"

  native_networkconf_id = unifi_network.this.id
  poe_mode              = "off"
}

resource "unifi_device" "usw_24_poe" {
  mac = "60:22:32:5c:60:7c"

  dynamic "port_override" {
    for_each = toset(var.usw_24_poe_harvester_ports)
    content {
      number          = port_override.value
      name            = "${var.default_network_name}-${port_override.value}"
      port_profile_id = unifi_port_profile.this.id
    }
  }
}

resource "unifi_device" "udm_pro" {
  mac = "ac:8b:a9:25:42:95"

  dynamic "port_override" {
    for_each = toset(var.udm_harvester_ports)
    content {
      number          = port_override.value
      name            = "${var.default_network_name}-${port_override.value}"
      port_profile_id = unifi_port_profile.this.id
    }
  }
}

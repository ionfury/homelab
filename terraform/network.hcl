locals {
  default_network_tld = "tomnowak.work"
  default_network_name = "citadel"
  default_network_vlan = 10
  default_network_cidr = "192.168.${local.default_network_vlan}.0/24"

  unifi_management_address = "https://192.168.1.1"
  unifi_management_username = "terraform"
  unifi_management_password_store = "unifi-password"
}

variable "default_network_tld" {
  type = string
}

variable "default_network_name" {
  type = string
}

variable "default_network_vlan" {
  type = number
}

variable "default_network_cidr" {
  type = string
}

variable "udm_harvester_ports" {
  default = [2, 4, 6]
}

variable "usw_24_poe_harvester_ports" {
  default = [14, 16, 17, 18, 19, 20, 21, 22, 24]
}

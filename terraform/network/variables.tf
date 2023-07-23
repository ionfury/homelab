variable "aws_region" {
  type        = string
  description = "AWS Region to use."
}

variable "aws_profile" {
  type        = string
  description = "AWS profile to use vis `~/.aws`."
}

variable "unifi_management_address" {
  type        = string
  description = "Unifi management address controlling the local network."
}

variable "unifi_management_username" {
  type        = string
  description = "Unifi management address login username."
}

variable "unifi_management_password_store" {
  type        = string
  description = "Name of AWS parameter store containing the unifi management password."
}

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

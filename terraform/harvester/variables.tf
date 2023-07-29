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

variable "harvester_node_count" {
  type        = number
  description = "The number of harvester nodes configured in this cluster."
}

variable "harvester_kubeconfig_path" {
  type = string
}


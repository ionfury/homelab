variable "tld" {
  description = "Top Level Domain name."
  type        = string
}

variable "aws" {
  type = object({
    region  = string
    profile = string
  })
}

variable "harvester" {
  description = "Configuration for the harvester instance."
  type = object({
    cluster_name       = string
    kubeconfig_path    = string
    management_address = string
    network_name       = string
    node_count         = number

    storage = map(object({
      name       = string
      selector   = string
      is_default = bool
    }))

    uplink = list(string)
  })
}

variable "networks" {
  type = map(object({
    name = string
    vlan = number
    cidr = string
  }))
}

variable "public_ssh_keys" {
  type = list(object({
    description = string
    name        = string
    public_key  = string
  }))
}

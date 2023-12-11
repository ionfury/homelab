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
  type = object({
    cluster_name       = string
    kubeconfig_path    = string
    management_address = string
    network_name       = string

    node_count = number
    uplink     = list(string)

    storage = map(object({
      name       = string
      selector   = string
      is_default = bool
    }))

    inventory = map(object({
      primary_disk = string
      mac          = string
      host         = string
      ip           = string
      port         = string
      insecure_tls = string
      credentials = object({
        store         = string
        username_path = string
        password_path = string
      })
    }))
  })
}

variable "networks" {
  type = map(object({
    name       = string
    vlan       = number
    cidr       = string
    gateway    = string
    netmask    = string
    dhcp_cidr  = string
    dhcp_start = number
    dhcp_stop  = number
    site       = string
  }))
}

variable "public_ssh_keys" {
  type = list(object({
    description = string
    name        = string
    public_key  = string
  }))
}

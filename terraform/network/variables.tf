variable "tld" {
  type = string
}

variable "aws" {
  type = object({
    region  = string
    profile = string
  })
}

variable "unifi" {
  type = object({
    address        = string
    username       = string
    password_store = string
    devices = map(object({
      mac  = string
      name = string
      port_overrides = list(object({
        network = string
        port    = number
      }))
    }))
  })
}

variable "networks" {
  type = map(object({
    name       = string
    vlan       = number
    cidr       = string
    dhcp_start = number
    dhcp_stop  = number
    site       = string
  }))
}

variable "harvester" {
  type = map(object({
    cluster_name       = string
    kubeconfig_path    = string
    management_address = string
    network_name       = string

    storage = map(object({
      name       = string
      selector   = string
      is_default = bool
    }))

    inventory = map(object({
      primary_disk = string
      mac          = string
      host         = string
      uplink       = list(string)
      ip           = string
      port         = string
      insecure_tls = string
      credentials = object({
        store         = string
        username_path = string
        password_path = string
      })
    }))

    uplink     = list(string)
    node_count = number
  }))
}

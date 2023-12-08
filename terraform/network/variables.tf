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

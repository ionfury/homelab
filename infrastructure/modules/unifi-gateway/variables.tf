variable "port_forwards" {
  description = "Port forwarding rules to create on the Unifi gateway."
  type = map(object({
    name     = string
    dst_port = string
    fwd_ip   = string
    fwd_port = string
    protocol = string
  }))
}

variable "unifi" {
  description = "Unifi controller configuration."
  type = object({
    address       = string
    site          = string
    api_key_store = string
  })
}

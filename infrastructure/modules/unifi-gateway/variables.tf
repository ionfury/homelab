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

variable "dynamic_dns" {
  description = "Dynamic DNS entries maintained on the Unifi gateway. Password is read from SSM at the given store path."
  type = map(object({
    service        = string
    host_name      = string
    server         = string
    login          = string
    password_store = string
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

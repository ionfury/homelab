variable "dns_records" {
  description = "DNS records to create in Unifi."
  type = map(object({
    name   = string
    record = string
  }))
}

variable "dhcp_reservations" {
  description = "Static DHCP reservations."
  type = map(object({
    mac = string
    ip  = string
  }))
}

variable "unifi" {
  description = "The Unifi controller to use."
  type = object({
    address       = string
    site          = string
    api_key_store = string
  })
}

variable "port_forwards" {
  description = "Port forwarding rules to create."
  type = map(object({
    name     = string
    dst_port = string
    fwd_ip   = string
    fwd_port = string
    protocol = string
  }))
}

variable "dynamic_dns" {
  description = "Dynamic DNS records to create."
  type = map(object({
    service        = string
    host_name      = string
    server         = string
    password_store = string
  }))
}

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
    address = string
    site    = string
    api_key = string
  })
}

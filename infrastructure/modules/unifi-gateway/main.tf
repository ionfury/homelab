resource "unifi_port_forward" "http" {
  name     = "External Gateway HTTP"
  dst_port = "80"
  fwd_ip   = var.external_ingress_ip
  fwd_port = "80"
  protocol = "tcp"
}

resource "unifi_port_forward" "https" {
  name     = "External Gateway HTTPS"
  dst_port = "443"
  fwd_ip   = var.external_ingress_ip
  fwd_port = "443"
  protocol = "tcp"
}

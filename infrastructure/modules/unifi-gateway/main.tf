resource "unifi_port_forward" "rule" {
  for_each = var.port_forwards

  name     = each.value.name
  dst_port = each.value.dst_port
  fwd_ip   = each.value.fwd_ip
  fwd_port = each.value.fwd_port
  protocol = each.value.protocol
}

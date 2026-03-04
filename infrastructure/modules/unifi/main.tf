resource "unifi_dns_record" "record" {
  for_each = var.dns_records

  name    = each.value.name
  record  = each.value.record
  enabled = true
  type    = "A"
  ttl     = 0
}

resource "unifi_user" "user" {
  for_each = var.dhcp_reservations

  name     = each.key
  mac      = each.value.mac
  fixed_ip = each.value.ip
  note     = "Managed by Terraform."
}

resource "unifi_port_forward" "rule" {
  for_each = var.port_forwards

  name     = each.value.name
  dst_port = each.value.dst_port
  fwd_ip   = each.value.fwd_ip
  fwd_port = each.value.fwd_port
  protocol = each.value.protocol
}

data "aws_ssm_parameter" "ddns_password" {
  for_each = var.dynamic_dns

  name = each.value.password_store
}

resource "unifi_dynamic_dns" "record" {
  for_each = var.dynamic_dns

  service   = each.value.service
  host_name = each.value.host_name
  server    = each.value.server
  password  = data.aws_ssm_parameter.ddns_password[each.key].value
}

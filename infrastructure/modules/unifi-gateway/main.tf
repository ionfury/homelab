data "aws_ssm_parameter" "ddns_password" {
  for_each = var.dynamic_dns

  name = each.value.password_store
}

resource "unifi_dynamic_dns" "record" {
  for_each = var.dynamic_dns

  service   = each.value.service
  host_name = each.value.host_name
  server    = each.value.server
  login     = each.value.login
  password  = data.aws_ssm_parameter.ddns_password[each.key].value
}

resource "unifi_port_forward" "rule" {
  for_each = var.port_forwards

  name     = each.value.name
  dst_port = each.value.dst_port
  fwd_ip   = each.value.fwd_ip
  fwd_port = each.value.fwd_port
  protocol = each.value.protocol
}

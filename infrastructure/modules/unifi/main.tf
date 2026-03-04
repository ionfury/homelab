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

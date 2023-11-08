resource "harvester_ssh_key" "keys" {
  for_each = {
    for index, key in var.public_ssh_keys : key.name => key
  }

  description = each.value.description
  name        = each.value.name
  public_key  = each.value.public_key
}

locals {
  inventory_vars = read_terragrunt_config(find_in_parent_folders("inventory.hcl"))

  cluster_name     = "dev"
  cluster_endpoint = "${local.cluster_name}.k8s.${local.inventory_vars.locals.tld}"

  hosts = tomap({
    for name, details in local.inventory_vars.locals.hosts :
    name => details
    if details.cluster == local.cluster_name
  })

  unifi_dns_records = tomap({
    for node, details in local.hosts :
    node => {
      name  = "${local.cluster_endpoint}"
      value = details.interfaces[0].addresses[0]
    }
  })

  unifi_users = tomap({
    for node, details in local.hosts :
    node => {
      mac = details.interfaces[0].hardwareAddr
      ip  = details.interfaces[0].addresses[0]
    }
  })
}

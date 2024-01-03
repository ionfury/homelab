data "aws_ssm_parameter" "credentials" {
  for_each = var.harvester.inventory

  name = each.value.ipmi.credentials.store
}

/*
resource "kubectl_manifest" "inventory_secret" {
  for_each = var.harvester.inventory

  yaml_body = <<YAML
apiVersion: v1
data:
  username: ${base64encode(jsondecode(data.aws_ssm_parameter.credentials[each.key].value)[each.value.credentials.username_path])}
  password: ${base64encode(jsondecode(data.aws_ssm_parameter.credentials[each.key].value)[each.value.credentials.password_path])}
kind: Secret
metadata:
  name: "${each.key}-inventory"
  namespace: default
type: Opaque
YAML
}

resource "kubectl_manifest" "inventory" {
  for_each = var.harvester.inventory

  yaml_body = <<YAML
apiVersion: metal.harvesterhci.io/v1alpha1
kind: Inventory
metadata:
  name: ${each.key}
  namespace: default
spec:
  primaryDisk: "${each.value.primary_disk}"
  managementInterfaceMacAddress: "${each.value.mac}"
  baseboardSpec:
    connection:
      host: "${each.value.ip}"
      port: ${each.value.port}
      insecureTLS: ${each.value.insecure_tls}
      authSecretRef:
        name: "${each.key}-inventory"
        namespace: default
  events:
    enabled: true
    pollingInterval: "1h"
YAML
}

resource "kubectl_manifest" "node_address_pool" {
  yaml_body = <<YAML
apiVersion: metal.harvesterhci.io/v1alpha1
kind: AddressPool
metadata:
  name: "${var.harvester.network_name}-pool"
  namespace: default
spec:
  cidr: "${var.networks[var.harvester.network_name].dhcp_cidr}"
  gateway: "${var.networks[var.harvester.network_name].gateway}"
  netmask: "${var.networks[var.harvester.network_name].netmask}"
YAML
}
*/

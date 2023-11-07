resource "kubectl_manifest" "rancher_harvester_provisioning" {
  provider = kubectl.rancher

  yaml_body = <<YAML
apiVersion: provisioning.cattle.io/v1
kind: Cluster
metadata:
  name: ${var.harvester.cluster_name}
  labels:
    provider.cattle.io: harvester
  namespace: fleet-default
spec:
  localClusterAuthEndpoint:
__clone: true
YAML
}

data "rancher2_cluster_v2" "homelab" {
  depends_on = [kubectl_manifest.rancher_harvester_provisioning]
  name       = var.harvester.cluster_name
}

resource "kubectl_manifest" "rancher_harvester_binding" {
  provider = kubectl.harvester

  yaml_body = <<YAML
apiVersion: harvesterhci.io/v1beta1
kind: Setting
metadata:
  name: cluster-registration-url
value: "${data.rancher2_cluster_v2.homelab.cluster_registration_token[0].manifest_url}"
YAML
}

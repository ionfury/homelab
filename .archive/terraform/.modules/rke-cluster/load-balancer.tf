resource "kubectl_manifest" "loadbalancer" {
  yaml_body = <<YAML
apiVersion: loadbalancer.harvesterhci.io/v1beta1
kind: LoadBalancer
metadata:
  name: "${var.name}"
  namespace: "${var.namespace}"
spec:
  backendServerSelector:
    tag.harvesterhci.io/managed-by-terraform:
    - "true"
  healthCheck: {}
  ipam: dhcp
  listeners:
  - backendPort: 443
    name: https
    port: 443
    protocol: TCP
  workloadType: vm
  healthCheck:
    port: 443
YAML
}
# tag.harvesterhci.io/vm-set:
#   - "${var.name}"

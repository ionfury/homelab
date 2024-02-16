data "rancher2_cluster_v2" "harvester" {
  name = var.harvester_cluster_name
}

resource "rancher2_cloud_credential" "harvester" {
  name = var.harvester_cluster_name
  harvester_credential_config {
    cluster_id         = data.rancher2_cluster_v2.harvester.cluster_v1_id
    cluster_type       = "imported"
    kubeconfig_content = data.rancher2_cluster_v2.harvester.kube_config
  }
}
resource "random_string" "random" {
  length  = 6
  special = false
  lower   = true
  upper   = false
}

locals {
  service_account_name                     = "harvester-cloud-provider-${var.name}"
  harvester_cloud_provider_kubeconfig_path = "~/.kube/harvester-cloud-provider-kubeconfig-${var.name}.yaml"
  cloud_provider_secret_name               = "harvester-config-${random_string.random.result}"
  cloud_provider_secret_namespace          = "fleet-default"
}

resource "null_resource" "curl_harvester_cloud_provider" {
  depends_on = [rancher2_cloud_credential.harvester]

  triggers = {
    cluster_id = data.rancher2_cluster_v2.harvester.cluster_v1_id
  }

  provisioner "local-exec" {
    command = <<EOF
curl -k -X POST ${var.rancher_admin_url}/k8s/clusters/${data.rancher2_cluster_v2.harvester.cluster_v1_id}/v1/harvester/kubeconfig \
  -H 'Content-Typecation/json' \
  -H "Authorization: Bearer ${var.rancher_admin_token}" \
  -d '{"clusterRoleName": "harvesterhci.io:cloudprovider", "namespace": "${var.namespace}", "serviceAccountName": "'${local.service_account_name}'"}' | xargs | sed 's/\\n/\n/g' > ${pathexpand("${local.harvester_cloud_provider_kubeconfig_path}")}
EOF
  }
}

data "local_file" "cloud_provider_kubeconfig" {
  depends_on = [null_resource.curl_harvester_cloud_provider]
  filename   = pathexpand("${local.harvester_cloud_provider_kubeconfig_path}")
}

resource "kubectl_manifest" "harvester_cloud_provider_secret" {
  depends_on = [data.local_file.cloud_provider_kubeconfig]
  yaml_body  = <<YAML
apiVersion: v1
data:
  credential: "${data.local_file.cloud_provider_kubeconfig.content_base64}"
kind: Secret
metadata:
  name: "${local.cloud_provider_secret_name}"
  namespace: "${local.cloud_provider_secret_namespace}"
  annotations:
  annotations:
    v2prov-authorized-secret-deletes-on-cluster-removal: "true"
    v2prov-secret-authorized-for-cluster: "${var.name}"
type: Opaque
YAML
}

resource "harvester_image" "this" {
  name         = var.image_name
  display_name = var.image_name
  namespace    = var.image_namespace
  source_type  = "download"
  url          = var.image
}

resource "rancher2_machine_config_v2" "machines" {
  for_each = var.machine_pools

  generate_name = "${var.name}-${each.key}"

  harvester_config {
    vm_namespace = var.namespace
    cpu_count    = each.value.resources.cpu
    memory_size  = each.value.resources.memory
    ssh_user     = var.image_ssh_user

    vm_affinity = each.value.vm_affinity_b64

    disk_info = <<EOF
    {
      "disks": [{
        "imageName": "${harvester_image.this.namespace}/${harvester_image.this.name}",
        "size": ${each.value.resources.disk},
        "bootOrder": 1
      }]
    }
    EOF

    network_info = <<EOF
    {
      "interfaces": [{
        "networkName": "default/${var.network_name}"
      }]
    }
    EOF

    user_data = <<EOF
      package_update: true
      packages:
        - qemu-guest-agent
        - iptables
      runcmd:
        - sed -i '/swap/s/^/#/' /etc/fstab
        - swapoff -a
        - - systemctl
          - enable
          - '--now'
          - qemu-guest-agent.service
    EOF
  }
}

resource "rancher2_cluster_v2" "cluster" {
  depends_on = [kubectl_manifest.harvester_cloud_provider_secret]

  name               = var.name
  kubernetes_version = var.kubernetes_version

  cloud_credential_secret_name = rancher2_cloud_credential.harvester.id

  default_pod_security_admission_configuration_template_name = "warn-rancher-restricted"

  rke_config {
    dynamic "machine_pools" {
      iterator = pool
      for_each = var.machine_pools

      content {
        name                         = pool.key
        cloud_credential_secret_name = rancher2_cloud_credential.harvester.id

        control_plane_role = pool.value.roles.control_plane
        etcd_role          = pool.value.roles.etcd
        worker_role        = pool.value.roles.worker

        quantity = pool.value.min_size

        node_startup_timeout_seconds   = pool.value.node_startup_timeout_seconds
        unhealthy_node_timeout_seconds = pool.value.unhealthy_node_timeout_seconds
        max_unhealthy                  = pool.value.max_unhealthy
        machine_labels                 = pool.value.machine_labels

        annotations = {
          "cluster.provisioning.cattle.io/autoscaler-min-size" = "${pool.value.min_size}"
          "cluster.provisioning.cattle.io/autoscaler-max-size" = "${pool.value.max_size}"
        }

        machine_config {
          kind = rancher2_machine_config_v2.machines[pool.key].kind
          name = rancher2_machine_config_v2.machines[pool.key].name
        }
      }
    }
    machine_selector_config {
      config = {
        cloud-provider-config = "secret://${local.cloud_provider_secret_namespace}:${local.cloud_provider_secret_name}"
        cloud-provider-name   = "harvester"
      }
    }
    registries {
    }
    machine_global_config = <<EOF
cni: canal
disable:
  - rke2-ingress-nginx
disable-kube-proxy: false
etcd-expose-metrics: true
embedded-registry: true
kube-apiserver-arg:
- admission-control-config-file=/etc/rancher/rke2/config/rancher-psact.yaml
EOF
    upgrade_strategy {
      control_plane_concurrency = "10%"
      worker_concurrency        = "10%"
    }
    chart_values = <<EOF
harvester-cloud-provider:
  cloudConfigPath: /var/lib/rancher/rke2/etc/config-files/cloud-provider-config
rke2-canal: {}
EOF
  }
}

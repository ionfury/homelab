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
  -d '{"clusterRoleName": "harvesterhci.io:cloudprovider", "namespace": "default", "serviceAccountName": "'harvester-cloud-provider'"}' | xargs | sed 's/\\n/\n/g' > ${pathexpand("~/.kube/harvester-cloud-provider-kubeconfig.yaml")}
EOF
  }
}

data "local_file" "cloud_provider_kubeconfig" {
  depends_on = [null_resource.curl_harvester_cloud_provider]
  filename   = pathexpand("~/.kube/harvester-cloud-provider-kubeconfig.yaml")
}

resource "harvester_image" "this" {
  name         = var.image_name
  display_name = var.image_name
  namespace    = var.image_namespace
  source_type  = "download"
  url          = var.image
}

resource "rancher2_machine_config_v2" "control_plane" {
  generate_name = "${var.name}-control-plane"
  harvester_config {
    vm_namespace = var.namespace
    cpu_count    = var.control_plane_cpu
    memory_size  = var.control_plane_memory
    disk_info    = <<EOF
    {
      "disks": [{
        "imageName": "${harvester_image.this.namespace}/${harvester_image.this.name}",
        "size": ${var.control_plane_disk},
        "bootOrder": 1
      }]
    }
    EOF
    network_info = <<EOF
    {
      "interfaces": [{
        "networkname": "default/${var.network_name}"
      }]
    }
    EOF
    ssh_user     = var.image_ssh_user
    user_data    = <<EOF
      package_update: true
      packages:
        - qemu-guest-agent
        - iptables
      runcmd:
        - - systemctl
          - enable
          - '--now'
          - qemu-guest-agent.service
    EOF
  }
}

resource "rancher2_machine_config_v2" "worker" {
  generate_name = "${var.name}-worker"
  harvester_config {
    vm_namespace = var.namespace
    cpu_count    = var.worker_cpu
    memory_size  = var.worker_memory
    disk_info    = <<EOF
    {
      "disks": [{
        "imageName": "${harvester_image.this.namespace}/${harvester_image.this.name}",
        "size": ${var.worker_disk},
        "bootOrder": 1
      }]
    }
    EOF
    network_info = <<EOF
    {
      "interfaces": [{
        "networkname": "default/${var.network_name}"
      }]
    }
    EOF
    ssh_user     = var.image_ssh_user
    user_data    = <<EOF
      package_update: true
      packages:
        - qemu-guest-agent
        - iptables
      runcmd:
        - - systemctl
          - enable
          - '--now'
          - qemu-guest-agent.service
    EOF
  }
}

resource "rancher2_cluster_v2" "cluster" {
  depends_on = [data.local_file.cloud_provider_kubeconfig]

  name               = var.name
  kubernetes_version = var.kubernetes_version
  rke_config {
    machine_pools {
      name                           = "control-plane"
      cloud_credential_secret_name   = rancher2_cloud_credential.harvester.id
      control_plane_role             = true
      etcd_role                      = true
      worker_role                    = false
      quantity                       = var.control_plane_node_count
      node_startup_timeout_seconds   = 1200
      unhealthy_node_timeout_seconds = 120
      max_unhealthy                  = "1"
      machine_config {
        kind = rancher2_machine_config_v2.control_plane.kind
        name = rancher2_machine_config_v2.control_plane.name
      }
    }
    machine_pools {
      name                           = "worker"
      cloud_credential_secret_name   = rancher2_cloud_credential.harvester.id
      control_plane_role             = false
      etcd_role                      = false
      worker_role                    = true
      quantity                       = var.worker_node_count
      node_startup_timeout_seconds   = 1200
      unhealthy_node_timeout_seconds = 120
      max_unhealthy                  = "1"
      machine_config {
        kind = rancher2_machine_config_v2.worker.kind
        name = rancher2_machine_config_v2.worker.name
      }
    }
    machine_selector_config {
      config = {
        cloud-provider-config = data.local_file.cloud_provider_kubeconfig.content
        cloud-provider-name   = "harvester"
      }
    }
    machine_global_config = <<EOF
cni: canal
disable:
  - rke2-ingress-nginx
disable-kube-proxy: false
etcd-expose-metrics: true
EOF
    upgrade_strategy {
      control_plane_concurrency = "10%"
      worker_concurrency        = "10%"
    }
    chart_values = <<EOF
harvester-csi-provider:
  image:
    harvester:
      csiDriver:
        tag: v0.1.4
        # Required for specifying storageclass defined in the host cluster https://github.com/harvester/harvester-csi-driver/releases/tag/v0.1.4
harvester-cloud-provider:
  clusterName: ${var.name}
  cloudConfigPath: /var/lib/rancher/rke2/etc/config-files/cloud-provider-config
EOF
  }
}

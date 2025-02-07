locals {
  cluster_name = "${basename(get_terragrunt_dir())}"
  tld          = "tomnowak.work"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/cluster.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.33.0"
}

inputs = {
  cluster_name     = local.cluster_name
  cluster_endpoint = "${local.cluster_name}.k8s.${local.tld}"
  tld              = local.tld

  cluster_vip            = "192.168.10.7"
  cluster_node_subnet    = "192.168.10.0/24"
  cluster_pod_subnet     = "172.20.0.0/16"
  cluster_service_subnet = "172.21.0.0/16"

  prepare_longhorn     = false
  longhorn_mount_disk2 = false
  prepare_spegel       = false
  speedy_kernel_args   = false

  kubernetes_version = "1.32.1"
  talos_version      = "v1.9.3"
  flux_version       = "v2.4.0"
  prometheus_version = "17.0.2"
  cilium_version     = "1.17.0"

  timeout = "20m" # pi is slow

  machines = {
    rpi2 = {
      type = "controlplane"
      install = {
        diskSelectors = ["serial: '0xb12d61b0'"]
        architecture  = "arm64"
        platform      = ""
        sbc           = "rpi_generic"
      }
      disks = []
      interfaces = [{
        hardwareAddr = "dc:a6:32:00:ce:5c"
        addresses    = ["192.168.10.168"]
      }]
    }
  }

  cilium_helm_values = <<EOT
ipam:
  mode: kubernetes
kubeProxyReplacement: true
cgroup:
  autoMount:
    enabled: false
  hostRoot: /sys/fs/cgroup
k8sServiceHost: 127.0.0.1
k8sServicePort: 7445
securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
      - NET_RAW
      - IPC_LOCK
      - SYS_ADMIN
      - SYS_RESOURCE
      - PERFMON
      - BPF
      - DAC_OVERRIDE
      - FOWNER
      - SETGID
      - SETUID
    cleanCiliumState:
      - NET_ADMIN
      - SYS_ADMIN
      - SYS_RESOURCE
EOT
}

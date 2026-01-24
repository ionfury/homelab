# Plan tests for talos module - validates Talos cluster provisioning

variables {
  talos_version      = "v1.9.0"
  kubernetes_version = "1.32.0"
  bootstrap_charts   = []
}

run "single_controlplane" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector = "disk.model = *"
        }
        configs = [
          <<-EOT
          cluster:
            clusterName: talos.local
            controlPlane:
              endpoint: https://talos.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: host1
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.10/24
          EOT
        ]
      }
    ]
  }

  assert {
    condition     = talos_machine_configuration_apply.machines["host1"].endpoint == "10.10.10.10"
    error_message = "Incorrect endpoint set for talos machine configuration apply"
  }

  assert {
    condition     = talos_machine_bootstrap.this.endpoint == "10.10.10.10"
    error_message = "Talos bootstrap endpoint incorrect: ${talos_machine_bootstrap.this.endpoint}"
  }

  assert {
    condition     = talos_machine_bootstrap.this.node == "10.10.10.10"
    error_message = "Incorrect host for talos machine bootstrap node"
  }

  assert {
    condition     = data.talos_client_configuration.this.endpoints[0] == "10.10.10.10"
    error_message = "Talos client configuration controlplane ip incorrect: ${talos_machine_bootstrap.this.endpoint}"
  }

  assert {
    condition     = data.talos_client_configuration.this.nodes[0] == "10.10.10.10"
    error_message = "Incorrect talos client configuration nodes"
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].talos_version == "v1.9.0"
    error_message = "Incorrect Talos version set for host1: ${data.talos_machine_configuration.this["host1"].talos_version}"
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].kubernetes_version == "1.32.0"
    error_message = "Incorrect Kubernetes version set for host1: ${data.talos_machine_configuration.this["host1"].kubernetes_version}"
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].machine_type == "controlplane"
    error_message = "Incorrect machine type set for host1: ${data.talos_machine_configuration.this["host1"].machine_type}"
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].cluster_name == "talos.local"
    error_message = "Incorrect cluster name set for host1: ${data.talos_machine_configuration.this["host1"].cluster_name}"
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].cluster_endpoint == "https://talos.local:6443"
    error_message = "Incorrect cluster endpoint set for host1: ${data.talos_machine_configuration.this["host1"].cluster_endpoint}"
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Incorrect number of talos machines configured: ${length(data.talos_machine_configuration.this)}"
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_metal) == 1
    error_message = "Incorrect length of returned metal machine image urls: ${length(data.talos_image_factory_urls.machine_image_url_metal)}"
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_sbc) == 0
    error_message = "Incorrect length of returned sbc machine image urls: ${length(data.talos_image_factory_urls.machine_image_url_sbc)}"
  }

  assert {
    condition     = strcontains(data.talos_machine_configuration.this["host1"].config_patches[0], "clusterName: talos.local")
    error_message = "ClusterName missing from host1 cluster.yaml.tftpl patch!"
  }

  # talos_image_factory_schematic.machine_schematic.id is not evaluated during a plan
  #assert {
  #  condition     = strcontains(data.talos_machine_configuration.this["host1"].config_patches[1], "asdf")
  #  error_message = length(data.talos_image_factory_urls.machine_image_url_metal)
  #}

  assert {
    condition     = strcontains(data.talos_machine_configuration.this["host1"].config_patches[1], "hostname: host1")
    error_message = "hostname missing from host1 HostnameConfig patch!"
  }
}

run "multi_node_cluster" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: multi-node.local
            controlPlane:
              endpoint: https://multi-node.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: cp1
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.11/24
          EOT
        ]
      },
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: multi-node.local
            controlPlane:
              endpoint: https://multi-node.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: cp2
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.12/24
          EOT
        ]
      },
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: multi-node.local
            controlPlane:
              endpoint: https://multi-node.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: cp3
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.13/24
          EOT
        ]
      }
    ]
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 3
    error_message = "Expected 3 machine configurations"
  }

  assert {
    condition     = length(data.talos_client_configuration.this.endpoints) == 3
    error_message = "Expected 3 controlplane endpoints"
  }

  assert {
    condition     = length(data.talos_client_configuration.this.nodes) == 3
    error_message = "Expected 3 nodes in client configuration"
  }

  assert {
    condition     = talos_machine_bootstrap.this.endpoint == "10.10.10.11"
    error_message = "Bootstrap should use first controlplane IP"
  }
}

run "mixed_controlplane_worker" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: mixed.local
            controlPlane:
              endpoint: https://mixed.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: cp1
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.20/24
          EOT
        ]
      },
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: mixed.local
            controlPlane:
              endpoint: https://mixed.local:6443
          machine:
            type: worker
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: worker1
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.21/24
          EOT
        ]
      },
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: mixed.local
            controlPlane:
              endpoint: https://mixed.local:6443
          machine:
            type: worker
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: worker2
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.22/24
          EOT
        ]
      }
    ]
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 3
    error_message = "Expected 3 machine configurations"
  }

  # Only controlplane should be in endpoints
  assert {
    condition     = length(data.talos_client_configuration.this.endpoints) == 1
    error_message = "Expected only 1 controlplane endpoint"
  }

  assert {
    condition     = data.talos_client_configuration.this.endpoints[0] == "10.10.10.20"
    error_message = "Endpoint should be controlplane IP"
  }

  # All nodes should be in nodes list
  assert {
    condition     = length(data.talos_client_configuration.this.nodes) == 3
    error_message = "All 3 nodes should be in client configuration nodes"
  }

  assert {
    condition     = data.talos_machine_configuration.this["cp1"].machine_type == "controlplane"
    error_message = "cp1 should be controlplane"
  }

  assert {
    condition     = data.talos_machine_configuration.this["worker1"].machine_type == "worker"
    error_message = "worker1 should be worker"
  }

  assert {
    condition     = data.talos_machine_configuration.this["worker2"].machine_type == "worker"
    error_message = "worker2 should be worker"
  }
}

run "worker_only" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: worker-only.local
            controlPlane:
              endpoint: https://worker-only.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: minimal-cp
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.30/24
          EOT
        ]
      },
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: worker-only.local
            controlPlane:
              endpoint: https://worker-only.local:6443
          machine:
            type: worker
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: worker1
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.31/24
          EOT
        ]
      }
    ]
  }

  assert {
    condition     = data.talos_machine_configuration.this["worker1"].machine_type == "worker"
    error_message = "worker1 should be worker type"
  }
}

run "version_propagation" {
  command = plan

  variables {
    talos_version      = "v1.10.0"
    kubernetes_version = "1.33.0"
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: version-test.local
            controlPlane:
              endpoint: https://version-test.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: host1
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: BondConfig
          name: bond0
          links:
            - link0_0
          bondMode: active-backup
          mtu: 1500
          addresses:
            - address: 10.10.10.40/24
          EOT
        ]
      }
    ]
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].talos_version == "v1.10.0"
    error_message = "Talos version should be v1.10.0"
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].kubernetes_version == "1.33.0"
    error_message = "Kubernetes version should be 1.33.0"
  }

  assert {
    condition     = talos_machine_secrets.this.talos_version == "v1.10.0"
    error_message = "Machine secrets should use specified Talos version"
  }
}

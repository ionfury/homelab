# Plan tests for talos module - validates Talos cluster provisioning

# Provider v0.11.0 regression: on_destroy.reset/graceful/reboot use bool
# instead of basetypes.BoolValue in the schema, crashing PlanResourceChange
# when any resource input is unknown (talos_machine_secrets not yet applied).
# override_resource skips PlanResourceChange entirely for these resources.
# Data sources depending on talos_machine_secrets are deferred during plan,
# so their output attributes are unknown — only structural (length) assertions
# and resource input attributes are assertable.
override_resource {
  target = talos_machine_configuration_apply.machines
  values = {}
}

override_resource {
  target = talos_machine_bootstrap.this
  values = {}
}

override_resource {
  target = talos_cluster_kubeconfig.this
  values = {}
}

override_data {
  target = data.talos_image_factory_extensions_versions.machine_version
  values = {
    extensions_info = []
  }
}

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
    condition     = talos_machine_bootstrap.this.node == "10.10.10.10"
    error_message = "Incorrect host for talos machine bootstrap node"
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
    condition     = talos_machine_bootstrap.this.node == "10.10.10.11"
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
    condition     = length(data.talos_machine_configuration.this) == 2
    error_message = "Expected 2 machine configurations"
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
    condition     = talos_machine_secrets.this.talos_version == "v1.10.0"
    error_message = "Machine secrets should use specified Talos version"
  }
}

# Edge case tests for talos module - on_destroy, custom paths, boundary conditions

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

  talos_machines = [
    {
      install = { selector = "disk.model = *" }
      configs = [
        <<-EOT
        cluster:
          clusterName: edge.local
          controlPlane:
            endpoint: https://edge.local:6443
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

run "on_destroy_default" {
  command = plan

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Machine should be configured with default on_destroy"
  }
}

run "on_destroy_graceful" {
  command = plan

  variables {
    on_destroy = {
      graceful = true
      reboot   = false
      reset    = false
    }
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Machine should be configured with graceful on_destroy"
  }
}

run "on_destroy_reset" {
  command = plan

  variables {
    on_destroy = {
      graceful = false
      reboot   = true
      reset    = true
    }
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Machine should be configured with reset on_destroy"
  }
}

run "custom_talos_config_path" {
  command = plan

  variables {
    talos_config_path = "/custom/path/talos"
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Custom talos config path should work"
  }
}

run "custom_kubernetes_config_path" {
  command = plan

  variables {
    kubernetes_config_path = "/custom/path/kube"
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Custom kubernetes config path should work"
  }
}

run "custom_timeout" {
  command = plan

  variables {
    talos_timeout = "20m"
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Custom timeout should work"
  }
}

run "disk_selector_by_size" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.size >= 100GB" }
        configs = [
          <<-EOT
          cluster:
            clusterName: selector.local
            controlPlane:
              endpoint: https://selector.local:6443
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
    condition     = data.talos_machine_disks.this["host1"].selector == "disk.size >= 100GB"
    error_message = "Disk selector should use custom size selector"
  }
}

run "disk_selector_by_model" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model == Samsung*" }
        configs = [
          <<-EOT
          cluster:
            clusterName: model.local
            controlPlane:
              endpoint: https://model.local:6443
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
    condition     = data.talos_machine_disks.this["host1"].selector == "disk.model == Samsung*"
    error_message = "Disk selector should use model selector"
  }
}

run "cluster_name_extraction" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: my-production-cluster
            controlPlane:
              endpoint: https://prod.example.com:6443
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
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Cluster name extraction should configure 1 machine"
  }
}

run "cluster_endpoint_extraction" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: endpoint-test
            controlPlane:
              endpoint: https://api.mycompany.internal:6443
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
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Cluster endpoint extraction should configure 1 machine"
  }
}

run "multiple_addresses_first_used" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        configs = [
          <<-EOT
          cluster:
            clusterName: multi-addr.local
            controlPlane:
              endpoint: https://multi-addr.local:6443
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
            - address: 10.10.20.10/24
          EOT
        ]
      }
    ]
  }

  assert {
    condition     = talos_machine_bootstrap.this.node == "10.10.10.10"
    error_message = "First address should be used as bootstrap node"
  }
}

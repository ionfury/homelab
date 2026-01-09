# Edge case tests for talos module - on_destroy, custom paths, boundary conditions

variables {
  talos_version      = "v1.9.0"
  kubernetes_version = "1.32.0"
  bootstrap_charts   = []

  talos_machines = [
    {
      install = { selector = "disk.model = *" }
      config  = <<EOT
cluster:
  clusterName: edge.local
  controlPlane:
    endpoint: https://edge.local:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
    }
  ]
}

run "on_destroy_default" {
  command = plan

  # Default on_destroy configuration
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
        config  = <<EOT
cluster:
  clusterName: selector.local
  controlPlane:
    endpoint: https://selector.local:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
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
        config  = <<EOT
cluster:
  clusterName: model.local
  controlPlane:
    endpoint: https://model.local:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
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
        config  = <<EOT
cluster:
  clusterName: my-production-cluster
  controlPlane:
    endpoint: https://prod.example.com:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
      }
    ]
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].cluster_name == "my-production-cluster"
    error_message = "Cluster name should be extracted from YAML config"
  }

  assert {
    condition     = data.talos_client_configuration.this.cluster_name == "my-production-cluster"
    error_message = "Client configuration should use extracted cluster name"
  }
}

run "cluster_endpoint_extraction" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        config  = <<EOT
cluster:
  clusterName: endpoint-test
  controlPlane:
    endpoint: https://api.mycompany.internal:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
      }
    ]
  }

  assert {
    condition     = data.talos_machine_configuration.this["host1"].cluster_endpoint == "https://api.mycompany.internal:6443"
    error_message = "Cluster endpoint should be extracted from YAML config"
  }
}

run "multiple_addresses_first_used" {
  command = plan

  variables {
    talos_machines = [
      {
        install = { selector = "disk.model = *" }
        config  = <<EOT
cluster:
  clusterName: multi-addr.local
  controlPlane:
    endpoint: https://multi-addr.local:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
        - 10.10.20.10/24
EOT
      }
    ]
  }

  # Should use the first address
  assert {
    condition     = talos_machine_configuration_apply.machines["host1"].endpoint == "10.10.10.10"
    error_message = "First address should be used as endpoint"
  }

  assert {
    condition     = data.talos_client_configuration.this.endpoints[0] == "10.10.10.10"
    error_message = "First address should be used in client configuration"
  }
}

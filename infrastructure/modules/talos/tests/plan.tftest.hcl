run "plan" {
  command = plan

  variables {
    talos_version      = "v1.9.0"
    kubernetes_version = "1.32.0"
    bootstrap_charts   = []

    talos_machines = [
      {
        install = {
          selector = "disk.model = *"
        }
        config = <<EOT
cluster:
  clusterName: talos.local
  controlPlane:
    endpoint: https://talos.local:6443
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
    condition     = strcontains(data.talos_machine_configuration.this["host1"].config_patches[0], "hostname: host1")
    error_message = "hostname missing from host1 each.value.config patch!"
  }
}


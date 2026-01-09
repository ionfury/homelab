# Image variant tests for talos module - ARM64, SBC, secureboot, extensions

variables {
  talos_version      = "v1.9.0"
  kubernetes_version = "1.32.0"
  bootstrap_charts   = []
}

run "amd64_metal_default" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector     = "disk.model = *"
          architecture = "amd64"
          platform     = "metal"
        }
        config = <<EOT
cluster:
  clusterName: amd64.local
  controlPlane:
    endpoint: https://amd64.local:6443
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
    condition     = length(data.talos_image_factory_urls.machine_image_url_metal) == 1
    error_message = "Expected 1 metal image URL"
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_sbc) == 0
    error_message = "Expected 0 SBC image URLs for metal platform"
  }
}

run "arm64_architecture" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          platform     = "metal"
        }
        config = <<EOT
cluster:
  clusterName: arm64.local
  controlPlane:
    endpoint: https://arm64.local:6443
machine:
  type: controlplane
  network:
    hostname: rpi1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
      }
    ]
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_metal) == 1
    error_message = "ARM64 metal should generate image URL"
  }
}

run "sbc_platform_rpi" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          platform     = ""
          sbc          = "rpi_generic"
        }
        config = <<EOT
cluster:
  clusterName: sbc.local
  controlPlane:
    endpoint: https://sbc.local:6443
machine:
  type: controlplane
  network:
    hostname: rpi1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
      }
    ]
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_sbc) == 1
    error_message = "SBC platform should generate SBC image URL"
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_metal) == 0
    error_message = "SBC platform should not generate metal image URL"
  }
}

run "secureboot_enabled" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector   = "disk.model = *"
          secureboot = true
        }
        config = <<EOT
cluster:
  clusterName: secureboot.local
  controlPlane:
    endpoint: https://secureboot.local:6443
machine:
  type: controlplane
  network:
    hostname: secure1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
      }
    ]
  }

  # Secureboot should use different installer image
  assert {
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Secureboot machine should be configured"
  }
}

run "secureboot_disabled_default" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector = "disk.model = *"
        }
        config = <<EOT
cluster:
  clusterName: nosecure.local
  controlPlane:
    endpoint: https://nosecure.local:6443
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
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Default (no secureboot) machine should be configured"
  }
}

run "with_extensions" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector   = "disk.model = *"
          extensions = ["siderolabs/iscsi-tools", "siderolabs/util-linux-tools"]
        }
        config = <<EOT
cluster:
  clusterName: extensions.local
  controlPlane:
    endpoint: https://extensions.local:6443
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
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Machine with extensions should be configured"
  }
}

run "extra_kernel_args" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector          = "disk.model = *"
          extra_kernel_args = ["console=ttyS0", "nomodeset"]
        }
        config = <<EOT
cluster:
  clusterName: kernelargs.local
  controlPlane:
    endpoint: https://kernelargs.local:6443
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
    condition     = length(data.talos_machine_configuration.this) == 1
    error_message = "Machine with extra kernel args should be configured"
  }
}

run "mixed_architectures" {
  command = plan

  variables {
    talos_machines = [
      {
        install = {
          selector     = "disk.model = *"
          architecture = "amd64"
          platform     = "metal"
        }
        config = <<EOT
cluster:
  clusterName: mixed-arch.local
  controlPlane:
    endpoint: https://mixed-arch.local:6443
machine:
  type: controlplane
  network:
    hostname: x86-cp
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
      },
      {
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          platform     = ""
          sbc          = "rpi_generic"
        }
        config = <<EOT
cluster:
  clusterName: mixed-arch.local
  controlPlane:
    endpoint: https://mixed-arch.local:6443
machine:
  type: worker
  network:
    hostname: rpi-worker
    interfaces:
      - addresses:
        - 10.10.10.11/24
EOT
      }
    ]
  }

  assert {
    condition     = length(data.talos_machine_configuration.this) == 2
    error_message = "Both architectures should be configured"
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_metal) == 1
    error_message = "Expected 1 metal image URL for amd64"
  }

  assert {
    condition     = length(data.talos_image_factory_urls.machine_image_url_sbc) == 1
    error_message = "Expected 1 SBC image URL for arm64 rpi"
  }
}

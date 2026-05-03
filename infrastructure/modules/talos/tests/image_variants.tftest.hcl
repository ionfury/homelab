# Image variant tests for talos module - ARM64, SBC, secureboot, extensions

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
        configs = [
          <<-EOT
          cluster:
            clusterName: amd64.local
            controlPlane:
              endpoint: https://amd64.local:6443
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
        configs = [
          <<-EOT
          cluster:
            clusterName: arm64.local
            controlPlane:
              endpoint: https://arm64.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: rpi1
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
        configs = [
          <<-EOT
          cluster:
            clusterName: sbc.local
            controlPlane:
              endpoint: https://sbc.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: rpi1
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
        configs = [
          <<-EOT
          cluster:
            clusterName: secureboot.local
            controlPlane:
              endpoint: https://secureboot.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: secure1
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
        configs = [
          <<-EOT
          cluster:
            clusterName: nosecure.local
            controlPlane:
              endpoint: https://nosecure.local:6443
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
        configs = [
          <<-EOT
          cluster:
            clusterName: extensions.local
            controlPlane:
              endpoint: https://extensions.local:6443
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
        configs = [
          <<-EOT
          cluster:
            clusterName: kernelargs.local
            controlPlane:
              endpoint: https://kernelargs.local:6443
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
        configs = [
          <<-EOT
          cluster:
            clusterName: mixed-arch.local
            controlPlane:
              endpoint: https://mixed-arch.local:6443
          machine:
            type: controlplane
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: x86-cp
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
      },
      {
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          platform     = ""
          sbc          = "rpi_generic"
        }
        configs = [
          <<-EOT
          cluster:
            clusterName: mixed-arch.local
            controlPlane:
              endpoint: https://mixed-arch.local:6443
          machine:
            type: worker
          EOT
          ,
          <<-EOT
          apiVersion: v1alpha1
          kind: HostnameConfig
          hostname: rpi-worker
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

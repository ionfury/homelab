# NVIDIA GPU tests - validates per-machine GPU detection, kernel modules,
# and containerd runtime configuration for machines with NVIDIA extensions

variables {
  name = "test-cluster"

  bgp = {
    router_ip  = "192.168.10.1"
    router_asn = 64512
  }

  networking = {
    id                  = 1
    internal_tld        = "internal.test.local"
    external_tld        = "external.test.local"
    node_subnet         = "192.168.10.0/24"
    pod_subnet          = "172.18.0.0/16"
    service_subnet      = "172.19.0.0/16"
    vip                 = "192.168.10.20"
    ip_pool_start       = "192.168.10.21"
    internal_ingress_ip = "192.168.10.22"
    external_ingress_ip = "192.168.10.23"
    ip_pool_stop        = "192.168.10.29"
    bgp_asn             = 64513
    nameservers         = ["192.168.10.1"]
    timeservers         = ["0.pool.ntp.org"]
  }

  versions = {
    talos       = "v1.9.0"
    kubernetes  = "1.32.0"
    cilium      = "1.16.0"
    gateway_api = "v1.2.0"
    flux        = "v2.4.0"
    prometheus  = "20.0.0"
  }

  local_paths = {
    talos      = "~/.talos"
    kubernetes = "~/.kube"
  }

  accounts = {
    unifi = {
      address       = "https://192.168.1.1"
      site          = "default"
      api_key_store = "/test/unifi"
    }
    github = {
      org             = "testorg"
      repository      = "testrepo"
      repository_path = "clusters"
      token_store     = "/test/github"
    }
    external_secrets = {
      id_store     = "/test/es-id"
      secret_store = "/test/es-secret"
    }
    healthchecksio = {
      api_key_store = "/test/hc"
    }
  }

  # Minimal Cilium values template for testing
  cilium_values_template = <<-EOT
    cluster:
      name: $${cluster_name}
    ipv4NativeRoutingCIDR: $${cluster_pod_subnet}
    hubble:
      ui:
        ingress:
          hosts:
            - hubble.$${internal_domain}
  EOT

  # Default test machine - no GPU extensions
  machines = {
    node1 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = { selector = "disk.model = *" }
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
        addresses          = ["192.168.10.101"]
      }]
    }
  }
}

# Machine with NVIDIA extensions gets kernel modules
run "nvidia_kernel_modules" {
  command = plan

  variables {
    features = []
    machines = {
      gpu-node = {
        cluster = "test-cluster"
        type    = "worker"
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines["gpu-node"].kernel_modules) == 4
    error_message = "GPU machine should have 4 NVIDIA kernel modules"
  }

  assert {
    condition = anytrue([
      for m in output.machines["gpu-node"].kernel_modules :
      m.name == "nvidia"
    ])
    error_message = "Kernel modules should include nvidia"
  }

  assert {
    condition = anytrue([
      for m in output.machines["gpu-node"].kernel_modules :
      m.name == "nvidia_uvm"
    ])
    error_message = "Kernel modules should include nvidia_uvm"
  }
}

# GPU machines need no custom containerd config — nvidia-container-toolkit extension handles it
run "nvidia_no_containerd_config" {
  command = plan

  variables {
    features = []
    machines = {
      gpu-node = {
        cluster = "test-cluster"
        type    = "worker"
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines["gpu-node"].files) == 0
    error_message = "GPU machine should have no containerd config files (extension handles runtime registration)"
  }
}

# Machine WITHOUT NVIDIA extensions gets no GPU config
run "no_nvidia_no_gpu_config" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.kernel_modules) == 0
    ])
    error_message = "Non-GPU machines should have no kernel modules"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 0
    ])
    error_message = "Non-GPU machines should have no files"
  }
}

# Mixed cluster - only GPU node gets GPU config
run "mixed_cluster_gpu_selective" {
  command = plan

  variables {
    features = []
    machines = {
      cp1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
      gpu-worker = {
        cluster = "test-cluster"
        type    = "worker"
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines["cp1"].kernel_modules) == 0
    error_message = "Non-GPU controlplane should have no kernel modules"
  }

  assert {
    condition     = length(output.machines["gpu-worker"].kernel_modules) == 4
    error_message = "GPU worker should have 4 NVIDIA kernel modules"
  }

  assert {
    condition     = length(output.machines["cp1"].files) == 0
    error_message = "Non-GPU controlplane should have no files"
  }

  assert {
    condition     = length(output.machines["gpu-worker"].files) == 0
    error_message = "GPU worker should have no containerd config files"
  }
}

# GPU node with spegel — only spegel containerd config (no nvidia config needed)
run "nvidia_with_spegel" {
  command = plan

  variables {
    features = ["spegel"]
    machines = {
      gpu-node = {
        cluster = "test-cluster"
        type    = "worker"
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines["gpu-node"].files) == 1
    error_message = "GPU machine with spegel should have 1 file (spegel only)"
  }

  assert {
    condition = anytrue([
      for f in output.machines["gpu-node"].files :
      f.path == "/etc/cri/conf.d/20-customization.part"
    ])
    error_message = "Spegel containerd config should be present"
  }
}

# NVIDIA kernel modules appear in Talos machine config
run "nvidia_in_talos_config" {
  command = plan

  variables {
    features = []
    machines = {
      gpu-node = {
        cluster = "test-cluster"
        type    = "worker"
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "kernel:")
    ])
    error_message = "Talos config should contain kernel section for GPU nodes"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "name: nvidia")
    ])
    error_message = "Talos config should list nvidia kernel module"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "name: nvidia_uvm")
    ])
    error_message = "Talos config should list nvidia_uvm kernel module"
  }
}

# NVIDIA extensions preserved in install output
run "nvidia_extensions_in_install" {
  command = plan

  variables {
    features = []
    machines = {
      gpu-node = {
        cluster = "test-cluster"
        type    = "worker"
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "nonfree-kmod-nvidia-production")
    ])
    error_message = "Install output should contain nonfree-kmod-nvidia-production extension"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "nvidia-container-toolkit-production")
    ])
    error_message = "Install output should contain nvidia-container-toolkit-production extension"
  }
}

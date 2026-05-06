# Hugepages feature tests - validates per-node hugepages allocation via sysctl (2M)
# and kernel cmdline (1G), selective application, and coexistence with other features

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

# 2M hugepages → sysctl output
run "hugepages_2m_emits_sysctl" {
  command = plan

  variables {
    features = []
    machines = {
      hp-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        features = {
          hugepages = { size = "2M", count = 512 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition     = output.machines["hp-node"].sysctls["vm.nr_hugepages"] == "512"
    error_message = "2M hugepages should emit vm.nr_hugepages sysctl with page count as string"
  }

  assert {
    condition     = length(output.machines["hp-node"].sysctls) == 1
    error_message = "2M hugepages should emit exactly one sysctl"
  }
}

# 2M hugepages → no hugepage kernel args
run "hugepages_2m_no_kernel_args" {
  command = plan

  variables {
    features = []
    machines = {
      hp-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        features = {
          hugepages = { size = "2M", count = 512 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition = !anytrue([
      for arg in output.machines["hp-node"].install.extra_kernel_args :
      startswith(arg, "hugepage")
    ])
    error_message = "2M hugepages should not add hugepage kernel args"
  }
}

# 2M hugepages → rendered in Talos machine YAML
run "hugepages_2m_in_talos_yaml" {
  command = plan

  variables {
    features = []
    machines = {
      hp-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        features = {
          hugepages = { size = "2M", count = 512 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "sysctls:")
    ])
    error_message = "Talos config should contain sysctls: section"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "vm.nr_hugepages")
    ])
    error_message = "Talos config should contain vm.nr_hugepages sysctl"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "\"512\"")
    ])
    error_message = "Talos config should contain hugepage count 512"
  }
}

# 1G hugepages → kernel cmdline args
run "hugepages_1g_emits_kernel_args" {
  command = plan

  variables {
    features = []
    machines = {
      hp-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        features = {
          hugepages = { size = "1G", count = 8 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition     = contains(output.machines["hp-node"].install.extra_kernel_args, "default_hugepagesz=1G")
    error_message = "1G hugepages should add default_hugepagesz=1G kernel arg"
  }

  assert {
    condition     = contains(output.machines["hp-node"].install.extra_kernel_args, "hugepagesz=1G")
    error_message = "1G hugepages should add hugepagesz=1G kernel arg"
  }

  assert {
    condition     = contains(output.machines["hp-node"].install.extra_kernel_args, "hugepages=8")
    error_message = "1G hugepages should add hugepages=8 kernel arg"
  }

  assert {
    condition     = length(output.machines["hp-node"].sysctls) == 0
    error_message = "1G hugepages should not emit any sysctls"
  }
}

# 1G hugepages → install output contains kernel args
run "hugepages_1g_in_install_output" {
  command = plan

  variables {
    features = []
    machines = {
      hp-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        features = {
          hugepages = { size = "1G", count = 8 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extra_kernel_args, "hugepages=8")
    ])
    error_message = "Install output should contain 1G hugepages kernel arg"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.configs), "sysctls:")
    ])
    error_message = "Talos config should not contain sysctls section for 1G hugepages"
  }
}

# No hugepages feature → no sysctls, no kernel args
run "no_hugepages_no_config" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.sysctls) == 0
    ])
    error_message = "Nodes without hugepages should have no sysctls"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      !anytrue([for arg in m.install.extra_kernel_args : startswith(arg, "hugepage")])
    ])
    error_message = "Nodes without hugepages should have no hugepage kernel args"
  }
}

# Mixed cluster — each node gets only its own config
run "mixed_cluster_selective" {
  command = plan

  variables {
    features = []
    machines = {
      plain = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
      hp-2m = {
        cluster = "test-cluster"
        type    = "worker"
        features = {
          hugepages = { size = "2M", count = 256 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
      hp-1g = {
        cluster = "test-cluster"
        type    = "worker"
        features = {
          hugepages = { size = "1G", count = 4 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:03"]
          addresses          = ["192.168.10.103"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines["plain"].sysctls) == 0
    error_message = "Plain node should have no sysctls"
  }

  assert {
    condition     = output.machines["hp-2m"].sysctls["vm.nr_hugepages"] == "256"
    error_message = "2M node should have vm.nr_hugepages = 256"
  }

  assert {
    condition     = length(output.machines["hp-2m"].sysctls) == 1
    error_message = "2M node should have exactly one sysctl"
  }

  assert {
    condition     = length(output.machines["hp-1g"].sysctls) == 0
    error_message = "1G node should have no sysctls"
  }

  assert {
    condition     = contains(output.machines["hp-1g"].install.extra_kernel_args, "hugepages=4")
    error_message = "1G node should have hugepages=4 kernel arg"
  }

  assert {
    condition = !anytrue([
      for arg in output.machines["plain"].install.extra_kernel_args :
      startswith(arg, "hugepage")
    ])
    error_message = "Plain node should have no hugepage kernel args"
  }

  assert {
    condition = !anytrue([
      for arg in output.machines["hp-2m"].install.extra_kernel_args :
      startswith(arg, "hugepage")
    ])
    error_message = "2M node should have no hugepage kernel args"
  }
}

# Hugepages coexists with NVIDIA
run "hugepages_coexists_with_nvidia" {
  command = plan

  variables {
    features = []
    machines = {
      gpu-hp-node = {
        cluster = "test-cluster"
        type    = "worker"
        features = {
          hugepages = { size = "2M", count = 1024 }
        }
        install = {
          selector   = "disk.model = *"
          extensions = ["nonfree-kmod-nvidia-production", "nvidia-container-toolkit-production"]
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines["gpu-hp-node"].kernel_modules) == 4
    error_message = "GPU+hugepages node should still have 4 NVIDIA kernel modules"
  }

  assert {
    condition     = output.machines["gpu-hp-node"].sysctls["vm.nr_hugepages"] == "1024"
    error_message = "GPU+hugepages node should have vm.nr_hugepages sysctl"
  }
}

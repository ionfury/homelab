# Edge case tests - validates boundary conditions and unusual configurations

variables {
  name = "test-cluster"

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

  # Default test machine - inherited by all run blocks
  machines = {
    node1 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = { selector = "disk.model = *" }
      interfaces = [{
        id           = "eth0"
        hardwareAddr = "aa:bb:cc:dd:ee:01"
        addresses    = [{ ip = "192.168.10.101" }]
      }]
    }
  }
}

# No features - clean minimal config
run "no_features_clean_config" {
  command = plan

  variables {
    features = []
  }

  # No longhorn artifacts
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.labels) == 0
    ])
    error_message = "No labels without features"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.annotations) == 0
    ])
    error_message = "No annotations without features"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 0
    ])
    error_message = "No files without features"
  }

  # No extraManifests
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(m.config, "extraManifests:")
    ])
    error_message = "No extraManifests without features"
  }

  # No controllerManager/scheduler/etcd extras
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(m.config, "controllerManager:")
    ])
    error_message = "No controllerManager section without prometheus"
  }
}

# Single node cluster - replica count should be 1
run "single_node_replica_count" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition     = length(output.machines) == 1
    error_message = "Should have exactly 1 machine"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars :
      v.name == "default_replica_count" && v.value == "1"
    ])
    error_message = "default_replica_count should be 1 for single node"
  }
}

# Three node cluster - replica count capped at 3
run "three_node_replica_count" {
  command = plan

  variables {
    features = []
    machines = {
      cp1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
      cp2 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:02"
          addresses    = [{ ip = "192.168.10.102" }]
        }]
      }
      cp3 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:03"
          addresses    = [{ ip = "192.168.10.103" }]
        }]
      }
    }
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars :
      v.name == "default_replica_count" && v.value == "3"
    ])
    error_message = "default_replica_count should be 3 for three nodes"
  }
}

# Five node cluster - replica count still capped at 3
run "five_node_replica_count_capped" {
  command = plan

  variables {
    features = []
    machines = {
      cp1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
      cp2 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:02"
          addresses    = [{ ip = "192.168.10.102" }]
        }]
      }
      cp3 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:03"
          addresses    = [{ ip = "192.168.10.103" }]
        }]
      }
      worker1 = {
        cluster = "test-cluster"
        type    = "worker"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:04"
          addresses    = [{ ip = "192.168.10.104" }]
        }]
      }
      worker2 = {
        cluster = "test-cluster"
        type    = "worker"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:05"
          addresses    = [{ ip = "192.168.10.105" }]
        }]
      }
    }
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars :
      v.name == "default_replica_count" && v.value == "3"
    ])
    error_message = "default_replica_count should be capped at 3 even with 5 nodes"
  }
}

# Worker-only filter - no VIP in config
run "worker_only_no_vip" {
  command = plan

  variables {
    features = []
    machines = {
      worker1 = {
        cluster = "test-cluster"
        type    = "worker"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(m.config, "vip:")
    ])
    error_message = "Worker nodes should not have VIP"
  }

  # No DNS records for workers
  assert {
    condition     = length(output.unifi.dns_records) == 0
    error_message = "Workers should not create DNS records"
  }

  # DHCP still created for workers
  assert {
    condition     = length(output.unifi.dhcp_reservations) == 1
    error_message = "Workers should still have DHCP reservations"
  }
}

# ARM64 architecture propagation
run "arm64_architecture" {
  command = plan

  variables {
    features = []
    machines = {
      rpi = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          platform     = ""
          sbc          = "rpi_generic"
        }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      m.install.architecture == "arm64"
    ])
    error_message = "ARM64 architecture should propagate to image spec"
  }
}

# SBC platform propagation
run "sbc_platform" {
  command = plan

  variables {
    features = []
    machines = {
      rpi = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          sbc          = "rpi_generic"
        }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      m.install.sbc == "rpi_generic"
    ])
    error_message = "SBC type should propagate to image spec"
  }
}

# Secureboot enabled propagation
run "secureboot_enabled" {
  command = plan

  variables {
    features = []
    machines = {
      secure = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector   = "disk.model = *"
          secureboot = true
        }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      m.install.secureboot == true
    ])
    error_message = "Secureboot flag should propagate to image spec"
  }
}

# Secureboot disabled by default
run "secureboot_default_false" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      m.install.secureboot == false
    ])
    error_message = "Secureboot should default to false"
  }
}

# All features combined - verify no conflicts
run "all_features_combined" {
  command = plan

  variables {
    features = ["gateway-api", "longhorn", "prometheus", "spegel"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector = "disk.model = *"
          data = {
            enabled = true
            tags    = ["fast"]
          }
        }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  # Longhorn extensions
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "iscsi-tools") &&
      contains(m.install.extensions, "util-linux-tools")
    ])
    error_message = "Longhorn extensions should be present"
  }

  # Longhorn labels
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.labels) == 1
    ])
    error_message = "Longhorn label should be present"
  }

  # Spegel files
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 1
    ])
    error_message = "Spegel file should be present"
  }

  # Prometheus extras
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "listen-metrics-urls")
    ])
    error_message = "Prometheus etcd config should be present"
  }

  # Gateway API manifest
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "experimental-install.yaml")
    ])
    error_message = "Gateway API manifest should be present"
  }

  # Both manifests in extraManifests
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "crd-servicemonitors.yaml") &&
      strcontains(m.config, "experimental-install.yaml")
    ])
    error_message = "Both prometheus and gateway-api manifests should be present"
  }
}

# Multi-interface machine
run "multi_interface_machine" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [
          {
            id           = "eth0"
            hardwareAddr = "aa:bb:cc:dd:ee:01"
            addresses    = [{ ip = "192.168.10.101" }]
          },
          {
            id           = "eth1"
            hardwareAddr = "aa:bb:cc:dd:ee:02"
            addresses    = [{ ip = "10.0.0.101" }]
          }
        ]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "192.168.10.101") &&
      strcontains(m.config, "10.0.0.101")
    ])
    error_message = "Both interface IPs should be in config"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "aa:bb:cc:dd:ee:01") &&
      strcontains(m.config, "aa:bb:cc:dd:ee:02")
    ])
    error_message = "Both interface MACs should be in config"
  }
}

# L2 interfaces collected for cluster env vars
run "l2_interfaces_env_var" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
      node2 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          id           = "enp0s3"
          hardwareAddr = "aa:bb:cc:dd:ee:02"
          addresses    = [{ ip = "192.168.10.102" }]
        }]
      }
    }
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars :
      v.name == "cluster_l2_interfaces" &&
      strcontains(v.value, "eth0") &&
      strcontains(v.value, "enp0s3")
    ])
    error_message = "cluster_l2_interfaces should contain both interface IDs"
  }
}

# Machine filtering - machines from other clusters excluded
run "other_cluster_machines_excluded" {
  command = plan

  variables {
    features = []
    machines = {
      test-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
      other-node = {
        cluster = "production"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:02"
          addresses    = [{ ip = "192.168.10.102" }]
        }]
      }
      another-node = {
        cluster = "staging"
        type    = "worker"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:03"
          addresses    = [{ ip = "192.168.10.103" }]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines) == 1
    error_message = "Only test-cluster machines should be included"
  }

  assert {
    condition     = contains(keys(output.machines), "test-node")
    error_message = "test-node should be in output"
  }

  assert {
    condition     = !contains(keys(output.machines), "other-node")
    error_message = "other-node should not be in output"
  }

  assert {
    condition     = !contains(keys(output.machines), "another-node")
    error_message = "another-node should not be in output"
  }
}


# Empty disks array - no disks section in config
run "empty_disks_no_section" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        disks   = []
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(m.config, "disks:")
    ])
    error_message = "Empty disks array should not create disks section"
  }
}

# On destroy configuration
run "on_destroy_config" {
  command = plan

  variables {
    features = []
    on_destroy = {
      graceful = true
      reboot   = false
      reset    = false
    }
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition     = output.talos.on_destroy.graceful == true
    error_message = "on_destroy.graceful should be true"
  }

  assert {
    condition     = output.talos.on_destroy.reboot == false
    error_message = "on_destroy.reboot should be false"
  }

  assert {
    condition     = output.talos.on_destroy.reset == false
    error_message = "on_destroy.reset should be false"
  }
}


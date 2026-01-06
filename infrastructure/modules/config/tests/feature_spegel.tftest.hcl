# Spegel feature tests - validates p2p image distribution configuration

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
}

# With spegel enabled - containerd config file created
run "spegel_file_created" {
  command = plan

  variables {
    features = ["spegel"]
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
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 1
    ])
    error_message = "Exactly one file should be created when spegel enabled"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      m.files[0].path == "/etc/cri/conf.d/20-customization.part"
    ])
    error_message = "Spegel config file should be at /etc/cri/conf.d/20-customization.part"
  }
}

# Spegel file content - discard_unpacked_layers must be false for p2p sharing
run "spegel_file_content" {
  command = plan

  variables {
    features = ["spegel"]
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
    condition = alltrue([
      for name, m in output.machines :
      strcontains(m.files[0].content, "discard_unpacked_layers = false")
    ])
    error_message = "File content must disable discard_unpacked_layers for spegel"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      strcontains(m.files[0].content, "io.containerd.cri.v1.images")
    ])
    error_message = "File must configure containerd CRI images plugin"
  }
}

# Spegel file permissions
run "spegel_file_permissions" {
  command = plan

  variables {
    features = ["spegel"]
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
    condition = alltrue([
      for name, m in output.machines :
      m.files[0].permissions == "0o666"
    ])
    error_message = "Spegel file should have 0o666 permissions"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      m.files[0].op == "create"
    ])
    error_message = "Spegel file operation should be 'create'"
  }
}

# Spegel config in Talos YAML
run "spegel_in_talos_config" {
  command = plan

  variables {
    features = ["spegel"]
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
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "files:")
    ])
    error_message = "Talos config should contain files section"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "/etc/cri/conf.d/20-customization.part")
    ])
    error_message = "Talos config should contain spegel file path"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "discard_unpacked_layers")
    ])
    error_message = "Talos config should contain spegel config content"
  }
}

# Multiple machines - all get spegel config
run "spegel_all_machines" {
  command = plan

  variables {
    features = ["spegel"]
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
      worker1 = {
        cluster = "test-cluster"
        type    = "worker"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:02"
          addresses    = [{ ip = "192.168.10.102" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 1
    ])
    error_message = "All machines should have spegel config file"
  }

  assert {
    condition     = length(output.talos.talos_machines) == 2
    error_message = "Both machines should be in talos output"
  }
}

# Without spegel - no files
run "no_spegel_no_files" {
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
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 0
    ])
    error_message = "No files should be created without spegel"
  }
}

# Without spegel - no files section in talos config
run "no_spegel_no_files_in_config" {
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
          hardwareAddr = "aa:bb:cc:dd:ee:01"
          addresses    = [{ ip = "192.168.10.101" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(m.config, "/etc/cri/conf.d/20-customization.part")
    ])
    error_message = "Talos config should not contain spegel file path without feature"
  }
}

# Spegel combined with other features
run "spegel_with_longhorn" {
  command = plan

  variables {
    features = ["spegel", "longhorn"]
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

  # Spegel file should still be present
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 1 &&
      m.files[0].path == "/etc/cri/conf.d/20-customization.part"
    ])
    error_message = "Spegel file should be present alongside longhorn"
  }

  # Longhorn extensions should also be present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "iscsi-tools")
    ])
    error_message = "Longhorn extensions should be present alongside spegel"
  }
}


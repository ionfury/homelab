# Gateway API feature tests - validates Kubernetes Gateway API CRD installation

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

# With gateway-api enabled - experimental CRD manifest added
run "gateway_api_manifest_present" {
  command = plan

  variables {
    features = ["gateway-api"]
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
      strcontains(m.config, "extraManifests:")
    ])
    error_message = "extraManifests section should be present when gateway-api enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "experimental-install.yaml")
    ])
    error_message = "Gateway API experimental-install.yaml should be in extraManifests"
  }
}

# Gateway API version in manifest URL
run "gateway_api_version_in_url" {
  command = plan

  variables {
    features = ["gateway-api"]
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
      strcontains(m.config, "v1.2.0")
    ])
    error_message = "Gateway API version v1.2.0 should be in manifest URL"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "kubernetes-sigs/gateway-api")
    ])
    error_message = "Manifest URL should reference kubernetes-sigs/gateway-api"
  }
}

# Custom gateway-api version
run "gateway_api_custom_version" {
  command = plan

  variables {
    features = ["gateway-api"]
    versions = {
      talos       = "v1.9.0"
      kubernetes  = "1.32.0"
      cilium      = "1.16.0"
      gateway_api = "v1.3.0"
      flux        = "v2.4.0"
      prometheus  = "20.0.0"
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
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "v1.3.0")
    ])
    error_message = "Custom Gateway API version v1.3.0 should be in manifest URL"
  }
}

# Full URL structure validation
run "gateway_api_full_url" {
  command = plan

  variables {
    features = ["gateway-api"]
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
      strcontains(m.config, "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/experimental-install.yaml")
    ])
    error_message = "Full Gateway API manifest URL should be correct"
  }
}

# Without gateway-api - no manifest
run "no_gateway_api_no_manifest" {
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
      !strcontains(m.config, "gateway-api")
    ])
    error_message = "Gateway API manifest should not be in config without feature"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(m.config, "experimental-install.yaml")
    ])
    error_message = "experimental-install.yaml should not be in config without gateway-api"
  }
}

# Gateway API alone - no extraManifests section if it's the only manifest
run "gateway_api_creates_extra_manifests_section" {
  command = plan

  variables {
    features = ["gateway-api"]
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
      strcontains(m.config, "extraManifests:")
    ])
    error_message = "extraManifests section should be created for gateway-api"
  }
}

# Multiple machines - all get gateway-api manifest
run "gateway_api_all_machines" {
  command = plan

  variables {
    features = ["gateway-api"]
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
      worker1 = {
        cluster = "test-cluster"
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
    condition     = length(output.talos.talos_machines) == 3
    error_message = "All 3 machines should be in talos output"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "experimental-install.yaml")
    ])
    error_message = "All machines should have gateway-api manifest in config"
  }
}

# Gateway API with all other features
run "gateway_api_with_all_features" {
  command = plan

  variables {
    features = ["gateway-api", "longhorn", "prometheus", "spegel"]
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

  # Gateway API manifest present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "experimental-install.yaml")
    ])
    error_message = "Gateway API manifest should be present with all features"
  }

  # Prometheus manifests present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "crd-servicemonitors.yaml")
    ])
    error_message = "Prometheus manifests should be present alongside gateway-api"
  }

  # Longhorn extensions present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "iscsi-tools")
    ])
    error_message = "Longhorn extensions should be present alongside gateway-api"
  }

  # Spegel files present
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.files) == 1
    ])
    error_message = "Spegel files should be present alongside gateway-api"
  }
}


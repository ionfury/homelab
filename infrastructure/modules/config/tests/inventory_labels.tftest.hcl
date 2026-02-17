# Inventory labels tests - validates that labels from inventory.hcl are merged
# with feature-derived labels in machine configuration

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

  # Default test machine - no inventory labels
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

# Inventory labels appear in machine output
run "inventory_labels_applied" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        labels = {
          "topology.homelab/rack" = "rack1"
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
    condition = anytrue([
      for l in output.machines["node1"].labels :
      l.key == "topology.homelab/rack" && l.value == "rack1"
    ])
    error_message = "Inventory labels should appear in machine labels"
  }
}

# Inventory labels merge with feature-derived labels (longhorn)
run "inventory_labels_merged_with_longhorn" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        labels = {
          "topology.homelab/rack" = "rack1"
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
    condition = anytrue([
      for l in output.machines["node1"].labels :
      l.key == "node.longhorn.io/create-default-disk" && l.value == "config"
    ])
    error_message = "Longhorn label should be present when longhorn feature enabled"
  }

  assert {
    condition = anytrue([
      for l in output.machines["node1"].labels :
      l.key == "topology.homelab/rack" && l.value == "rack1"
    ])
    error_message = "Inventory labels should be present alongside longhorn labels"
  }

  assert {
    condition     = length(output.machines["node1"].labels) == 2
    error_message = "Should have exactly 2 labels (longhorn + inventory)"
  }
}

# Inventory labels render in Talos machine config
run "inventory_labels_in_talos_config" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        labels = {
          "topology.homelab/rack" = "rack1"
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
      strcontains(join("\n", m.configs), "topology.homelab/rack")
    ])
    error_message = "Talos machine config should contain inventory label key"
  }
}

# No inventory labels defaults to empty - no labels without features
run "no_inventory_labels_no_features" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.labels) == 0
    ])
    error_message = "Machines without inventory labels and no features should have no labels"
  }
}

# Multiple inventory labels on a single machine
run "multiple_inventory_labels" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        labels = {
          "topology.homelab/rack" = "rack1"
          "topology.homelab/zone" = "zone-a"
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
    condition     = length(output.machines["node1"].labels) == 2
    error_message = "Should have exactly 2 inventory labels"
  }

  assert {
    condition = anytrue([
      for l in output.machines["node1"].labels :
      l.key == "topology.homelab/rack" && l.value == "rack1"
    ])
    error_message = "First inventory label should be present"
  }

  assert {
    condition = anytrue([
      for l in output.machines["node1"].labels :
      l.key == "topology.homelab/zone" && l.value == "zone-a"
    ])
    error_message = "Second inventory label should be present"
  }
}

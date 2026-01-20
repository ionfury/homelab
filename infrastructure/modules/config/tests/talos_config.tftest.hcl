# Talos config YAML structure tests - validates generated machine configuration

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
    nameservers         = ["192.168.10.1", "8.8.8.8"]
    timeservers         = ["0.pool.ntp.org", "1.pool.ntp.org"]
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
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
        addresses          = ["192.168.10.101"]
      }]
    }
  }
}

# Helper: join all configs for searching across documents
# Note: Each assertion uses join("\n", m.configs) to search across all documents

# Cluster endpoint from internal TLD
run "talos_cluster_endpoint" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "endpoint: https://k8s.internal.test.local:6443")
    ])
    error_message = "Cluster endpoint should be https://k8s.{internal_tld}:6443"
  }
}

# Cluster name in config
run "talos_cluster_name" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "clusterName: test-cluster")
    ])
    error_message = "Cluster name should match var.name"
  }
}

# Pod subnet configuration
run "talos_pod_subnet" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "podSubnets:") &&
      strcontains(join("\n", m.configs), "172.18.0.0/16")
    ])
    error_message = "Pod subnet should be configured from networking.pod_subnet"
  }
}

# Service subnet configuration
run "talos_service_subnet" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "serviceSubnets:") &&
      strcontains(join("\n", m.configs), "172.19.0.0/16")
    ])
    error_message = "Service subnet should be configured from networking.service_subnet"
  }
}

# Kube-proxy disabled (Cilium handles this)
run "talos_proxy_disabled" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "proxy:") &&
      strcontains(join("\n", m.configs), "disabled: true")
    ])
    error_message = "Kube-proxy should be disabled (Cilium replaces it)"
  }
}

# CNI set to none (Cilium is installed separately)
run "talos_cni_none" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "cni:") &&
      strcontains(join("\n", m.configs), "name: none")
    ])
    error_message = "CNI should be set to none (Cilium is installed separately)"
  }
}

# Machine type - controlplane
run "talos_machine_type_controlplane" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "type: controlplane")
    ])
    error_message = "Machine type should be controlplane"
  }
}

# Machine type - worker
run "talos_machine_type_worker" {
  command = plan

  variables {
    features = []
    machines = {
      worker1 = {
        cluster = "test-cluster"
        type    = "worker"
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
      strcontains(join("\n", m.configs), "type: worker")
    ])
    error_message = "Machine type should be worker"
  }
}

# Machine hostname from HostnameConfig document
run "talos_hostname" {
  command = plan

  variables {
    features = []
    machines = {
      my-special-node = {
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

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "kind: HostnameConfig") &&
      strcontains(join("\n", m.configs), "hostname: my-special-node")
    ])
    error_message = "HostnameConfig should contain machine name"
  }
}

# Bond configuration with addresses
run "talos_bond_config" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "kind: BondConfig")
    ])
    error_message = "BondConfig should be present"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "address: 192.168.10.101/24")
    ])
    error_message = "Bond should have address with /24 CIDR"
  }
}

# Link alias config with MAC address
run "talos_link_alias" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "kind: LinkAliasConfig")
    ])
    error_message = "LinkAliasConfig should be present"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "aa:bb:cc:dd:ee:01")
    ])
    error_message = "LinkAliasConfig should contain MAC address"
  }
}

# VIP only on controlplane nodes via Layer2VIPConfig
run "talos_vip_controlplane_only" {
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
      worker1 = {
        cluster = "test-cluster"
        type    = "worker"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  # Find the controlplane config - should have Layer2VIPConfig
  # Note: In Talos 1.12, the VIP address is the resource name (no separate address field)
  assert {
    condition = anytrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "type: controlplane") &&
      strcontains(join("\n", m.configs), "kind: Layer2VIPConfig") &&
      strcontains(join("\n", m.configs), "name: 192.168.10.20")
    ])
    error_message = "Controlplane should have Layer2VIPConfig with VIP as name"
  }

  # Worker config should not have Layer2VIPConfig
  assert {
    condition = anytrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "type: worker") &&
      !strcontains(join("\n", m.configs), "kind: Layer2VIPConfig")
    ])
    error_message = "Worker should not have Layer2VIPConfig"
  }
}

# Nameservers via ResolverConfig document
run "talos_nameservers" {
  command = plan

  variables {
    features = []
  }

  # ResolverConfig document should be present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      anytrue([for c in m.configs : strcontains(c, "kind: ResolverConfig")])
    ])
    error_message = "ResolverConfig document should be present in configs"
  }

  # Nameservers should be in the config
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "nameservers:") &&
      strcontains(join("\n", m.configs), "192.168.10.1") &&
      strcontains(join("\n", m.configs), "8.8.8.8")
    ])
    error_message = "Both nameservers should be in config"
  }
}

# Timeservers via TimeSyncConfig document
run "talos_timeservers" {
  command = plan

  variables {
    features = []
  }

  # TimeSyncConfig document should be present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      anytrue([for c in m.configs : strcontains(c, "kind: TimeSyncConfig")])
    ])
    error_message = "TimeSyncConfig document should be present in configs"
  }

  # Timeservers should be in the config
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "servers:") &&
      strcontains(join("\n", m.configs), "0.pool.ntp.org") &&
      strcontains(join("\n", m.configs), "1.pool.ntp.org")
    ])
    error_message = "Both timeservers should be in config"
  }
}

# Performance kernel args (in install block for schematic, not in configs YAML)
run "talos_kernel_args" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      length(m.install.extra_kernel_args) > 0
    ])
    error_message = "extra_kernel_args should be present in install block"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extra_kernel_args, "mitigations=off")
    ])
    error_message = "Performance kernel arg mitigations=off should be set"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extra_kernel_args, "apparmor=0")
    ])
    error_message = "Performance kernel arg apparmor=0 should be set"
  }
}

# Install wipe default
run "talos_install_wipe" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "wipe: true")
    ])
    error_message = "Install wipe should default to true"
  }
}

# Kubelet node IP valid subnets
run "talos_kubelet_node_ip" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "nodeIP:") &&
      strcontains(join("\n", m.configs), "validSubnets:") &&
      strcontains(join("\n", m.configs), "192.168.10.0/24")
    ])
    error_message = "Kubelet nodeIP validSubnets should match node_subnet"
  }
}

# Host DNS feature enabled
run "talos_host_dns" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "hostDNS:") &&
      strcontains(join("\n", m.configs), "enabled: true")
    ])
    error_message = "hostDNS should be enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "forwardKubeDNSToHost: true")
    ])
    error_message = "forwardKubeDNSToHost should be true"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "resolveMemberNames: true")
    ])
    error_message = "resolveMemberNames should be true"
  }
}

# Volume configuration via UserVolumeConfig
run "talos_volume_config" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        volumes = [{
          name     = "data"
          selector = "disk.dev_path == '/dev/sdb'"
          maxSize  = "100%"
          tags     = ["data"]
        }]
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
      strcontains(join("\n", m.configs), "kind: UserVolumeConfig") &&
      strcontains(join("\n", m.configs), "name: data") &&
      strcontains(join("\n", m.configs), "disk.dev_path == '/dev/sdb'") &&
      strcontains(join("\n", m.configs), "maxSize: 100%")
    ])
    error_message = "UserVolumeConfig should include volume name, selector, and maxSize"
  }
}

# Image spec - architecture
run "talos_image_architecture" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector     = "disk.model = *"
          architecture = "amd64"
          platform     = "metal"
        }
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
      m.install.architecture == "amd64"
    ])
    error_message = "Image architecture should be amd64"
  }
}

# Image spec - platform
run "talos_image_platform" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector = "disk.model = *"
          platform = "metal"
        }
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
      m.install.platform == "metal"
    ])
    error_message = "Image platform should be metal"
  }
}

# Allow scheduling on control planes
run "talos_allow_scheduling_controlplane" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "allowSchedulingOnControlPlanes: true")
    ])
    error_message = "allowSchedulingOnControlPlanes should be true"
  }
}

# API server pod security policy disabled
run "talos_api_server_psp_disabled" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "apiServer:") &&
      strcontains(join("\n", m.configs), "disablePodSecurityPolicy: true")
    ])
    error_message = "API server pod security policy should be disabled"
  }
}

# DHCPv4Config present for each bond
run "talos_dhcp_config" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "kind: DHCPv4Config")
    ])
    error_message = "DHCPv4Config should be present for bonds"
  }
}

# Multi-link bond configuration
run "talos_multi_link_bond" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01", "aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.101"]
          mode               = "802.3ad"
        }]
      }
    }
  }

  # Should have 2 LinkAliasConfig documents
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      length([for c in m.configs : c if strcontains(c, "kind: LinkAliasConfig")]) == 2
    ])
    error_message = "Should have 2 LinkAliasConfig documents for 2-link bond"
  }

  # Bond should reference both links
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "- link0_0") &&
      strcontains(join("\n", m.configs), "- link0_1")
    ])
    error_message = "BondConfig should reference both links"
  }

  # 802.3ad bond should have LACP settings
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "bondMode: 802.3ad") &&
      strcontains(join("\n", m.configs), "lacpRate: slow")
    ])
    error_message = "802.3ad bond should have LACP settings"
  }
}

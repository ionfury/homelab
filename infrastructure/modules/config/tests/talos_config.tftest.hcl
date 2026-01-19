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
    talos       = "v1.12.1"
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

# Cluster endpoint from internal TLD
run "talos_cluster_endpoint" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "endpoint: https://k8s.internal.test.local:6443")
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
      strcontains(join("\n", m.config_patches), "clusterName: test-cluster")
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
      strcontains(join("\n", m.config_patches), "podSubnets:") &&
      strcontains(join("\n", m.config_patches), "172.18.0.0/16")
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
      strcontains(join("\n", m.config_patches), "serviceSubnets:") &&
      strcontains(join("\n", m.config_patches), "172.19.0.0/16")
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
      strcontains(join("\n", m.config_patches), "proxy:") &&
      strcontains(join("\n", m.config_patches), "disabled: true")
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
      strcontains(join("\n", m.config_patches), "cni:") &&
      strcontains(join("\n", m.config_patches), "name: none")
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
      strcontains(join("\n", m.config_patches), "type: controlplane")
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
      strcontains(join("\n", m.config_patches), "type: worker")
    ])
    error_message = "Machine type should be worker"
  }
}

# Machine hostname from machine name - now via HostnameConfig document (Talos 1.12+)
run "talos_hostname" {
  command = plan

  variables {
    features = []
    machines = {
      my-special-node = {
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
      strcontains(join("\n", m.config_patches), "kind: HostnameConfig") &&
      strcontains(join("\n", m.config_patches), "hostname: my-special-node")
    ])
    error_message = "HostnameConfig document should contain hostname matching machine name"
  }
}

# Network interface IP addresses - now via LinkConfig document (Talos 1.12+)
run "talos_interface_addresses" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "kind: LinkConfig") &&
      strcontains(join("\n", m.config_patches), "address: 192.168.10.101/24")
    ])
    error_message = "LinkConfig should contain interface IP with /24 CIDR"
  }
}

# Hardware address matching via LinkAliasConfig CEL expression (Talos 1.12+)
run "talos_hardware_address" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "kind: LinkAliasConfig") &&
      strcontains(join("\n", m.config_patches), "mac(link.permanent_addr) == \"aa:bb:cc:dd:ee:01\"")
    ])
    error_message = "LinkAliasConfig should match hardware address via CEL expression"
  }
}

# VIP only on controlplane nodes - now via shared address in LinkConfig (Talos 1.12+)
run "talos_vip_controlplane_only" {
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

  # Find the controlplane config - should have VIP as shared address
  assert {
    condition = anytrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "type: controlplane") &&
      strcontains(join("\n", m.config_patches), "address: 192.168.10.20/32") &&
      strcontains(join("\n", m.config_patches), "shared: true")
    ])
    error_message = "Controlplane should have VIP configured as shared address"
  }

  # Worker config should not have shared VIP address
  assert {
    condition = anytrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "type: worker") &&
      !strcontains(join("\n", m.config_patches), "shared: true")
    ])
    error_message = "Worker should not have shared VIP address"
  }
}

# Nameservers from networking
run "talos_nameservers" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "nameservers:") &&
      strcontains(join("\n", m.config_patches), "192.168.10.1") &&
      strcontains(join("\n", m.config_patches), "8.8.8.8")
    ])
    error_message = "Both nameservers should be in config"
  }
}

# Timeservers from networking
run "talos_timeservers" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "servers:") &&
      strcontains(join("\n", m.config_patches), "0.pool.ntp.org") &&
      strcontains(join("\n", m.config_patches), "1.pool.ntp.org")
    ])
    error_message = "Both timeservers should be in config"
  }
}

# Performance kernel args - now in install section for image factory (Talos 1.12+)
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
    error_message = "extra_kernel_args should be present in install section"
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
      strcontains(join("\n", m.config_patches), "wipe: true")
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
      strcontains(join("\n", m.config_patches), "nodeIP:") &&
      strcontains(join("\n", m.config_patches), "validSubnets:") &&
      strcontains(join("\n", m.config_patches), "192.168.10.0/24")
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
      strcontains(join("\n", m.config_patches), "hostDNS:") &&
      strcontains(join("\n", m.config_patches), "enabled: true")
    ])
    error_message = "hostDNS should be enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "forwardKubeDNSToHost: true")
    ])
    error_message = "forwardKubeDNSToHost should be true"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "resolveMemberNames: true")
    ])
    error_message = "resolveMemberNames should be true"
  }
}

# Stable hostname disabled for static hostname support (Talos 1.12+)
run "talos_stable_hostname_disabled" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "stableHostname: false")
    ])
    error_message = "stableHostname should be false when static hostname is set"
  }
}

# Disk configuration for explicit disks
run "talos_disk_partitions" {
  command = plan

  variables {
    features = []
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        disks = [
          {
            device     = "/dev/sdb"
            mountpoint = "/var/mnt/data"
            tags       = ["data"]
          }
        ]
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
      strcontains(join("\n", m.config_patches), "disks:") &&
      strcontains(join("\n", m.config_patches), "device: /dev/sdb") &&
      strcontains(join("\n", m.config_patches), "mountpoint: /var/mnt/data")
    ])
    error_message = "Disk configuration should include device and mountpoint"
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
      strcontains(join("\n", m.config_patches), "allowSchedulingOnControlPlanes: true")
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
      strcontains(join("\n", m.config_patches), "apiServer:") &&
      strcontains(join("\n", m.config_patches), "disablePodSecurityPolicy: true")
    ])
    error_message = "API server pod security policy should be disabled"
  }
}

# ========================================
# Talos 1.12+ Modular Document Tests
# ========================================

# Multi-document YAML structure with document separators
run "talos_modular_document_separators" {
  command = plan

  variables {
    features = []
  }

  # Count modular config documents - should have at least 4: HostnameConfig, LinkAliasConfig, LinkConfig, DHCPv4Config
  # (machine config is the 5th document but uses legacy format without apiVersion)
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      length(regexall("kind: ", join("\n", m.config_patches))) >= 4
    ])
    error_message = "Config should contain at least 4 modular config documents with 'kind:'"
  }
}

# DHCPv4Config document for DHCP client configuration
run "talos_dhcpv4_config_document" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "kind: DHCPv4Config")
    ])
    error_message = "Config should contain DHCPv4Config document"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "clientIdentifier: mac")
    ])
    error_message = "DHCPv4Config should use MAC as client identifier"
  }
}

# DHCP route metric configuration
run "talos_dhcp_route_metric" {
  command = plan

  variables {
    features = []
    machines = {
      dhcp-test-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id               = "eth0"
          hardwareAddr     = "aa:bb:cc:dd:ee:99"
          dhcp_routeMetric = 200
          addresses        = [{ ip = "192.168.10.199" }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "routeMetric: 200")
    ])
    error_message = "DHCPv4Config should have custom route metric"
  }
}

# VLANConfig document when VLANs are configured
run "talos_vlan_config_document" {
  command = plan

  variables {
    features = []
    machines = {
      vlan-test-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        interfaces = [{
          id           = "eth0"
          hardwareAddr = "aa:bb:cc:dd:ee:88"
          addresses    = [{ ip = "192.168.10.188" }]
          vlans = [{
            vlanId    = 100
            addresses = [{ ip = "10.100.0.101", cidr = "24" }]
          }]
        }]
      }
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "kind: VLANConfig")
    ])
    error_message = "Config should contain VLANConfig document when VLANs are configured"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "vlanID: 100") &&
      strcontains(join("\n", m.config_patches), "parent: net0")
    ])
    error_message = "VLANConfig should have correct VLAN ID and parent interface"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "address: 10.100.0.101/24")
    ])
    error_message = "VLANConfig should have correct VLAN IP address"
  }
}

# No VLANConfig when no VLANs configured
run "talos_no_vlan_config_without_vlans" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "kind: VLANConfig")
    ])
    error_message = "Config should not contain VLANConfig when no VLANs are configured"
  }
}

# Old inline patterns should not be present (deviceSelector replaced by LinkAliasConfig)
run "talos_no_legacy_device_selector" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "deviceSelector:")
    ])
    error_message = "Config should not contain legacy deviceSelector (replaced by LinkAliasConfig)"
  }
}

# Old inline hostname should not be in machine.network section
run "talos_no_legacy_inline_hostname" {
  command = plan

  variables {
    features = []
  }

  # Verify hostname is only in HostnameConfig, not inline
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "network:\n    hostname:")
    ])
    error_message = "Config should not contain legacy inline hostname in machine.network"
  }
}

# LinkConfig has correct interface naming
run "talos_link_config_interface_naming" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "kind: LinkConfig") &&
      strcontains(join("\n", m.config_patches), "name: net0")
    ])
    error_message = "LinkConfig should use net0, net1, etc. interface naming"
  }
}

# LinkAliasConfig creates stable interface names
run "talos_link_alias_config_naming" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "kind: LinkAliasConfig") &&
      strcontains(join("\n", m.config_patches), "name: net0")
    ])
    error_message = "LinkAliasConfig should define net0 alias"
  }
}


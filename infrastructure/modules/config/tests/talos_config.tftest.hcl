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
      strcontains(m.config, "endpoint: https://k8s.internal.test.local:6443")
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
      strcontains(m.config, "clusterName: test-cluster")
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
      strcontains(m.config, "podSubnets:") &&
      strcontains(m.config, "172.18.0.0/16")
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
      strcontains(m.config, "serviceSubnets:") &&
      strcontains(m.config, "172.19.0.0/16")
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
      strcontains(m.config, "proxy:") &&
      strcontains(m.config, "disabled: true")
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
      strcontains(m.config, "cni:") &&
      strcontains(m.config, "name: none")
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
      strcontains(m.config, "type: controlplane")
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
      strcontains(m.config, "type: worker")
    ])
    error_message = "Machine type should be worker"
  }
}

# Machine hostname from machine name
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
      strcontains(m.config, "hostname: my-special-node")
    ])
    error_message = "Hostname should match machine name"
  }
}

# Network interface IP addresses
run "talos_interface_addresses" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "192.168.10.101/24")
    ])
    error_message = "Interface IP should be in config with /24 CIDR"
  }
}

# Hardware address in config
run "talos_hardware_address" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "hardwareAddr: \"aa:bb:cc:dd:ee:01\"")
    ])
    error_message = "Hardware address should be in config"
  }
}

# VIP only on controlplane nodes
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

  # Find the controlplane config - should have VIP
  assert {
    condition = anytrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "type: controlplane") &&
      strcontains(m.config, "vip:") &&
      strcontains(m.config, "ip: 192.168.10.20")
    ])
    error_message = "Controlplane should have VIP configured"
  }

  # Worker config should not have vip section
  assert {
    condition = anytrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "type: worker") &&
      !strcontains(m.config, "vip:")
    ])
    error_message = "Worker should not have VIP configured"
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
      strcontains(m.config, "nameservers:") &&
      strcontains(m.config, "192.168.10.1") &&
      strcontains(m.config, "8.8.8.8")
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
      strcontains(m.config, "servers:") &&
      strcontains(m.config, "0.pool.ntp.org") &&
      strcontains(m.config, "1.pool.ntp.org")
    ])
    error_message = "Both timeservers should be in config"
  }
}

# Performance kernel args
run "talos_kernel_args" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "extraKernelArgs:")
    ])
    error_message = "extraKernelArgs section should be present"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "mitigations=off")
    ])
    error_message = "Performance kernel arg mitigations=off should be set"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "apparmor=0")
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
      strcontains(m.config, "wipe: true")
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
      strcontains(m.config, "nodeIP:") &&
      strcontains(m.config, "validSubnets:") &&
      strcontains(m.config, "192.168.10.0/24")
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
      strcontains(m.config, "hostDNS:") &&
      strcontains(m.config, "enabled: true")
    ])
    error_message = "hostDNS should be enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "forwardKubeDNSToHost: true")
    ])
    error_message = "forwardKubeDNSToHost should be true"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "resolveMemberNames: true")
    ])
    error_message = "resolveMemberNames should be true"
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
      strcontains(m.config, "disks:") &&
      strcontains(m.config, "device: /dev/sdb") &&
      strcontains(m.config, "mountpoint: /var/mnt/data")
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
      strcontains(m.config, "allowSchedulingOnControlPlanes: true")
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
      strcontains(m.config, "apiServer:") &&
      strcontains(m.config, "disablePodSecurityPolicy: true")
    ])
    error_message = "API server pod security policy should be disabled"
  }
}


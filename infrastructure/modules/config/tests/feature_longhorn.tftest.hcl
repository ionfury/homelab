# Longhorn feature tests - validates storage-related configuration

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

# With longhorn enabled - iscsi and util-linux extensions required
run "longhorn_extensions_added" {
  command = plan

  variables {
    features = ["longhorn"]
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
      contains(m.install.extensions, "iscsi-tools")
    ])
    error_message = "iscsi-tools extension should be added when longhorn enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.install.extensions, "util-linux-tools")
    ])
    error_message = "util-linux-tools extension should be added when longhorn enabled"
  }
}

# Longhorn label for auto disk configuration
run "longhorn_label_added" {
  command = plan

  variables {
    features = ["longhorn"]
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      anytrue([
        for l in m.labels :
        l.key == "node.longhorn.io/create-default-disk" && l.value == "config"
      ])
    ])
    error_message = "Longhorn create-default-disk label should be set to 'config'"
  }
}

# Kubelet extra mount for longhorn data directory
run "longhorn_kubelet_mount" {
  command = plan

  variables {
    features = ["longhorn"]
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      anytrue([
        for mount in m.kubelet_extraMounts :
        mount.destination == "/var/lib/longhorn" &&
        mount.source == "/var/lib/longhorn" &&
        mount.type == "bind"
      ])
    ])
    error_message = "Longhorn kubelet mount should be configured at /var/lib/longhorn"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "/var/lib/longhorn")
    ])
    error_message = "Talos config should contain longhorn mount path"
  }
}

# Disk annotation with install.data.enabled = true
run "longhorn_annotation_with_data_enabled" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector = "disk.model = *"
          data = {
            enabled = true
            tags    = ["fast", "nvme"]
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

  assert {
    condition = alltrue([
      for name, m in output.machines :
      anytrue([
        for a in m.annotations :
        a.key == "node.longhorn.io/default-disks-config"
      ])
    ])
    error_message = "Longhorn disk config annotation should be present when data.enabled=true"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      anytrue([
        for a in m.annotations :
        a.key == "node.longhorn.io/default-disks-config" &&
        strcontains(a.value, "longhorn") &&
        strcontains(a.value, "fast") &&
        strcontains(a.value, "nvme")
      ])
    ])
    error_message = "Disk annotation should contain path and tags"
  }
}

# Disk annotation with explicit disks array
run "longhorn_annotation_with_explicit_disks" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector = "disk.model = *"
          data = {
            enabled = false
            tags    = []
          }
        }
        disks = [
          {
            device     = "/dev/sdb"
            mountpoint = "/var/mnt/storage"
            tags       = ["slow", "hdd"]
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
      for name, m in output.machines :
      anytrue([
        for a in m.annotations :
        a.key == "node.longhorn.io/default-disks-config" &&
        strcontains(a.value, "/var/mnt/storage") &&
        strcontains(a.value, "slow") &&
        strcontains(a.value, "hdd")
      ])
    ])
    error_message = "Disk annotation should contain explicit disk mountpoint and tags"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      anytrue([
        for mount in m.kubelet_extraMounts :
        mount.destination == "/var/mnt/storage"
      ])
    ])
    error_message = "Explicit disks should have kubelet mounts"
  }
}

# Combined: both data.enabled and explicit disks
run "longhorn_combined_disk_sources" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = {
          selector = "disk.model = *"
          data = {
            enabled = true
            tags    = ["primary"]
          }
        }
        disks = [
          {
            device     = "/dev/sdb"
            mountpoint = "/var/mnt/extra"
            tags       = ["secondary"]
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
      for name, m in output.machines :
      anytrue([
        for a in m.annotations :
        a.key == "node.longhorn.io/default-disks-config" &&
        strcontains(a.value, "longhorn") &&
        strcontains(a.value, "/var/mnt/extra")
      ])
    ])
    error_message = "Disk annotation should contain both data and explicit disk paths"
  }

  # Should have 2 mounts: longhorn + extra disk
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.kubelet_extraMounts) == 2
    ])
    error_message = "Should have 2 kubelet mounts (longhorn + explicit disk)"
  }
}

# Without longhorn - no storage extensions
run "no_longhorn_no_extensions" {
  command = plan

  variables {
    features = []
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

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !contains(m.install.extensions, "iscsi-tools")
    ])
    error_message = "iscsi-tools should not be added without longhorn"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !contains(m.install.extensions, "util-linux-tools")
    ])
    error_message = "util-linux-tools should not be added without longhorn"
  }
}

# Without longhorn - no labels
run "no_longhorn_no_labels" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.labels) == 0
    ])
    error_message = "No labels should be set without longhorn"
  }
}

# Without longhorn - no kubelet mounts (unless explicit disks exist)
run "no_longhorn_no_mount" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.kubelet_extraMounts) == 0
    ])
    error_message = "No kubelet mounts should be set without longhorn and no explicit disks"
  }
}

# Without longhorn - no disk annotations
run "no_longhorn_no_annotations" {
  command = plan

  variables {
    features = []
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

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.annotations) == 0
    ])
    error_message = "No annotations should be set without longhorn even if data.enabled=true"
  }
}


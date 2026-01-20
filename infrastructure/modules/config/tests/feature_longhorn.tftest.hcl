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
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
        addresses          = ["192.168.10.101"]
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

# Kubelet extra mount for longhorn data directory with system_disk volume
run "longhorn_kubelet_mount_system_disk" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        volumes = [{
          name     = "longhorn"
          selector = "system_disk == true"
          maxSize  = "50%"
          tags     = ["fast", "nvme"]
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
      for name, m in output.machines :
      anytrue([
        for mount in m.kubelet_extraMounts :
        mount.destination == "/var/lib/longhorn" &&
        mount.source == "/var/lib/longhorn" &&
        mount.type == "bind"
      ])
    ])
    error_message = "Longhorn kubelet mount should be configured at /var/lib/longhorn for system_disk volume"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "/var/lib/longhorn")
    ])
    error_message = "Talos config should contain longhorn mount path"
  }
}

# Disk annotation with system_disk volume
run "longhorn_annotation_with_system_disk_volume" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        volumes = [{
          name     = "longhorn"
          selector = "system_disk == true"
          maxSize  = "50%"
          tags     = ["fast", "nvme"]
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
      for name, m in output.machines :
      anytrue([
        for a in m.annotations :
        a.key == "node.longhorn.io/default-disks-config"
      ])
    ])
    error_message = "Longhorn disk config annotation should be present with volumes"
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

# Disk annotation with explicit non-system volume
run "longhorn_annotation_with_explicit_volume" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        volumes = [{
          name     = "storage"
          selector = "disk.dev_path == '/dev/sdb'"
          maxSize  = "100%"
          tags     = ["slow", "hdd"]
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
      for name, m in output.machines :
      anytrue([
        for a in m.annotations :
        a.key == "node.longhorn.io/default-disks-config" &&
        strcontains(a.value, "/var/mnt/storage") &&
        strcontains(a.value, "slow") &&
        strcontains(a.value, "hdd")
      ])
    ])
    error_message = "Disk annotation should contain explicit volume mountpoint and tags"
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      anytrue([
        for mount in m.kubelet_extraMounts :
        mount.destination == "/var/mnt/storage"
      ])
    ])
    error_message = "Explicit volumes should have kubelet mounts"
  }
}

# Combined: both system_disk and explicit volumes
run "longhorn_combined_volume_sources" {
  command = plan

  variables {
    features = ["longhorn"]
    machines = {
      node1 = {
        cluster = "test-cluster"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        volumes = [
          {
            name     = "primary"
            selector = "system_disk == true"
            maxSize  = "50%"
            tags     = ["primary"]
          },
          {
            name     = "extra"
            selector = "disk.dev_path == '/dev/sdb'"
            maxSize  = "100%"
            tags     = ["secondary"]
          }
        ]
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
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
    error_message = "Disk annotation should contain both system and explicit volume paths"
  }

  # Should have 2 mounts: longhorn + extra volume
  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.kubelet_extraMounts) == 2
    ])
    error_message = "Should have 2 kubelet mounts (longhorn + explicit volume)"
  }
}

# UserVolumeConfig generated for volumes
run "longhorn_user_volume_config" {
  command = plan

  variables {
    features = ["longhorn"]
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
      strcontains(join("\n", m.configs), "name: data")
    ])
    error_message = "UserVolumeConfig should be generated for volumes"
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
        install = { selector = "disk.model = *" }
        volumes = [{
          name     = "data"
          selector = "system_disk == true"
          maxSize  = "50%"
          tags     = ["fast"]
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

# Without longhorn - no kubelet mounts (unless explicit volumes exist)
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
    error_message = "No kubelet mounts should be set without longhorn and no volumes"
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
        install = { selector = "disk.model = *" }
        volumes = [{
          name     = "data"
          selector = "system_disk == true"
          maxSize  = "50%"
          tags     = ["fast"]
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
      for name, m in output.machines :
      length(m.annotations) == 0
    ])
    error_message = "No annotations should be set without longhorn even if volumes exist"
  }
}

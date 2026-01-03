variables {
  name     = "test-cluster"
  features = ["gateway-api", "longhorn", "prometheus", "spegel"]

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
    timeservers         = ["0.pool.ntp.org", "1.pool.ntp.org"]
  }

  machines = {
    node1 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = {
        selector     = "disk.size > 100u * GiB"
        architecture = "amd64"
        platform     = "metal"
        data = {
          enabled = true
          tags    = ["fast", "ssd"]
        }
      }
      disks = []
      interfaces = [{
        id           = "eth0"
        hardwareAddr = "aa:bb:cc:dd:ee:01"
        addresses    = [{ ip = "192.168.10.101" }]
      }]
    }
    node2 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = {
        selector     = "disk.size > 100u * GiB"
        architecture = "amd64"
        platform     = "metal"
        data = {
          enabled = false
          tags    = []
        }
      }
      disks = [
        {
          device     = "/dev/sda"
          mountpoint = "/var/mnt/disk1"
          tags       = ["fast", "ssd"]
        }
      ]
      interfaces = [{
        id           = "eth0"
        hardwareAddr = "aa:bb:cc:dd:ee:02"
        addresses    = [{ ip = "192.168.10.102" }]
      }]
    }
    node3 = {
      cluster = "other-cluster"
      type    = "controlplane"
      install = {
        selector = "disk.size > 100u * GiB"
      }
      interfaces = [{
        hardwareAddr = "aa:bb:cc:dd:ee:03"
        addresses    = [{ ip = "192.168.10.103" }]
      }]
    }
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

  values = {
    "/homelab/infrastructure/accounts/unifi/api-key"           = "test-unifi-key"
    "/homelab/infrastructure/accounts/github/token"            = "test-github-token"
    "/homelab/infrastructure/accounts/external-secrets/id"     = "test-es-id"
    "/homelab/infrastructure/accounts/external-secrets/secret" = "test-es-secret"
    "/homelab/infrastructure/accounts/healthchecksio/api-key"  = "test-hc-key"
  }

  accounts = {
    unifi = {
      address       = "https://192.168.1.1"
      site          = "default"
      api_key_store = "/homelab/infrastructure/accounts/unifi/api-key"
    }
    github = {
      org             = "testorg"
      repository      = "testrepo"
      repository_path = "kubernetes/clusters"
      token_store     = "/homelab/infrastructure/accounts/github/token"
    }
    external_secrets = {
      id_store     = "/homelab/infrastructure/accounts/external-secrets/id"
      secret_store = "/homelab/infrastructure/accounts/external-secrets/secret"
    }
    healthchecksio = {
      api_key_store = "/homelab/infrastructure/accounts/healthchecksio/api-key"
    }
  }
}

run "machine_filtering" {
  command = plan

  assert {
    condition     = length(output.machines) == 2
    error_message = "Expected 2 machines filtered by cluster name"
  }

  assert {
    condition     = contains(keys(output.machines), "node1")
    error_message = "Expected node1 in filtered machines"
  }

  assert {
    condition     = !contains(keys(output.machines), "node3")
    error_message = "node3 should be filtered out"
  }
}

run "cluster_endpoint" {
  command = plan

  assert {
    condition     = output.cluster_endpoint == "k8s.internal.test.local"
    error_message = "Incorrect cluster endpoint"
  }
}

run "unifi_output" {
  command = plan

  assert {
    condition     = length(output.unifi.dns_records) == 2
    error_message = "Expected 2 DNS records for control plane nodes"
  }

  assert {
    condition     = length(output.unifi.dhcp_reservations) == 2
    error_message = "Expected 2 DHCP reservations"
  }
}

run "talos_output" {
  command = plan

  assert {
    condition     = output.talos.talos_version == "v1.9.0"
    error_message = "Incorrect talos version"
  }

  assert {
    condition     = length(output.talos.talos_machines) == 2
    error_message = "Expected 2 talos machines"
  }
}

run "bootstrap_output" {
  command = plan

  assert {
    condition     = output.bootstrap.cluster_name == "test-cluster"
    error_message = "Incorrect cluster name"
  }

  assert {
    condition     = output.bootstrap.flux_version == "v2.4.0"
    error_message = "Incorrect flux version"
  }
}

run "cluster_env_vars" {
  command = plan

  assert {
    condition     = length(output.cluster_env_vars) > 10
    error_message = "Expected more than 10 cluster env vars"
  }
}

run "aws_set_params_output" {
  command = plan

  assert {
    condition     = output.aws_set_params.kubeconfig_path == "/homelab/infrastructure/clusters/test-cluster/kubeconfig"
    error_message = "Incorrect kubeconfig path"
  }
}

run "longhorn_extensions" {
  command = plan

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      contains(m.image.extensions, "iscsi-tools") && contains(m.image.extensions, "util-linux-tools")
    ])
    error_message = "Longhorn extensions not in machine image specs"
  }
}

run "longhorn_labels" {
  command = plan

  assert {
    condition = alltrue([
      for m in output.machines :
      anytrue([for l in m.labels : l.key == "node.longhorn.io/create-default-disk"])
    ])
    error_message = "Longhorn labels not in machines"
  }
}

run "spegel_files" {
  command = plan

  assert {
    condition = alltrue([
      for m in output.machines :
      anytrue([for f in m.files : f.path == "/etc/cri/conf.d/20-customization.part"])
    ])
    error_message = "Spegel files not in machines"
  }
}

run "prometheus_extraargs_in_config" {
  command = plan

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.config, "listen-metrics-urls")
    ])
    error_message = "Prometheus etcd extraArgs not in machine config"
  }
}

run "params_get" {
  command = plan

  assert {
    condition     = length(output.params_get) == 5
    error_message = "Expected 5 SSM parameters to fetch"
  }
}

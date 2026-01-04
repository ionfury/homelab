# Base tests for config module - validates core output structure and transformations

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
      install = {}
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

  account_values = {
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

# Machine filtering - only machines matching cluster name should be included
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
    condition     = contains(keys(output.machines), "node2")
    error_message = "Expected node2 in filtered machines"
  }

  assert {
    condition     = !contains(keys(output.machines), "node3")
    error_message = "node3 should be filtered out (different cluster)"
  }
}

# Cluster endpoint derived from internal TLD
run "cluster_endpoint" {
  command = plan

  assert {
    condition     = output.cluster_endpoint == "k8s.internal.test.local"
    error_message = "Cluster endpoint should be k8s.{internal_tld}"
  }

  assert {
    condition     = output.cluster_name == "test-cluster"
    error_message = "Cluster name should match input"
  }
}

# Unifi output structure - DNS and DHCP for network configuration
run "unifi_output_structure" {
  command = plan

  assert {
    condition     = length(output.unifi.dns_records) == 2
    error_message = "Expected 2 DNS records (one per controlplane node)"
  }

  assert {
    condition     = length(output.unifi.dhcp_reservations) == 2
    error_message = "Expected 2 DHCP reservations (one per machine)"
  }

  assert {
    condition     = output.unifi.address == "https://192.168.1.1"
    error_message = "Unifi address should be passed through"
  }

  assert {
    condition     = output.unifi.site == "default"
    error_message = "Unifi site should be passed through"
  }

  assert {
    condition     = output.unifi.api_key == "test-unifi-key"
    error_message = "Unifi API key should be resolved from account_values"
  }
}

# Talos output structure - versions and machine count
run "talos_output_structure" {
  command = plan

  assert {
    condition     = output.talos.talos_version == "v1.9.0"
    error_message = "Talos version should match input"
  }

  assert {
    condition     = output.talos.kubernetes_version == "1.32.0"
    error_message = "Kubernetes version should match input"
  }

  assert {
    condition     = length(output.talos.talos_machines) == 2
    error_message = "Expected 2 talos machines"
  }

  assert {
    condition     = output.talos.talos_config_path == "~/.talos"
    error_message = "Talos config path should match local_paths input"
  }

  assert {
    condition     = output.talos.kubernetes_config_path == "~/.kube"
    error_message = "Kubernetes config path should match local_paths input"
  }

  assert {
    condition     = output.talos.talos_timeout == "10m"
    error_message = "Talos timeout should be set"
  }
}

# Bootstrap output structure - flux and account bindings
run "bootstrap_output_structure" {
  command = plan

  assert {
    condition     = output.bootstrap.cluster_name == "test-cluster"
    error_message = "Bootstrap cluster name should match input"
  }

  assert {
    condition     = output.bootstrap.flux_version == "v2.4.0"
    error_message = "Flux version should match input"
  }

  assert {
    condition     = output.bootstrap.github.org == "testorg"
    error_message = "GitHub org should be passed through"
  }

  assert {
    condition     = output.bootstrap.github.repository == "testrepo"
    error_message = "GitHub repository should be passed through"
  }

  assert {
    condition     = output.bootstrap.github.token == "test-github-token"
    error_message = "GitHub token should be resolved from account_values"
  }

  assert {
    condition     = output.bootstrap.external_secrets.id == "test-es-id"
    error_message = "External secrets ID should be resolved from account_values"
  }

  assert {
    condition     = output.bootstrap.external_secrets.secret == "test-es-secret"
    error_message = "External secrets secret should be resolved from account_values"
  }

  assert {
    condition     = output.bootstrap.healthchecksio.api_key == "test-hc-key"
    error_message = "Healthchecks.io API key should be resolved from account_values"
  }
}

# AWS SSM output paths
run "aws_set_params_output" {
  command = plan

  assert {
    condition     = output.aws_set_params.kubeconfig_path == "/homelab/infrastructure/clusters/test-cluster/kubeconfig"
    error_message = "Kubeconfig SSM path should include cluster name"
  }

  assert {
    condition     = output.aws_set_params.talosconfig_path == "/homelab/infrastructure/clusters/test-cluster/talosconfig"
    error_message = "Talosconfig SSM path should include cluster name"
  }
}

# Cluster environment variables for flux post-build substitution
run "cluster_env_vars_content" {
  command = plan

  assert {
    condition     = length(output.cluster_env_vars) >= 15
    error_message = "Expected at least 15 cluster env vars"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "cluster_name" && v.value == "test-cluster"
    ])
    error_message = "cluster_name env var should be set"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "cluster_tld" && v.value == "internal.test.local"
    ])
    error_message = "cluster_tld env var should match internal_tld"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "cluster_vip" && v.value == "192.168.10.20"
    ])
    error_message = "cluster_vip env var should match networking.vip"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "cluster_pod_subnet" && v.value == "172.18.0.0/16"
    ])
    error_message = "cluster_pod_subnet env var should match networking.pod_subnet"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "talos_version" && v.value == "v1.9.0"
    ])
    error_message = "talos_version env var should match versions.talos"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "kubernetes_version" && v.value == "1.32.0"
    ])
    error_message = "kubernetes_version env var should match versions.kubernetes"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_env_vars : v.name == "cluster_id" && v.value == "1"
    ])
    error_message = "cluster_id env var should match networking.id"
  }
}

# SSM parameters to fetch
run "params_get_list" {
  command = plan

  assert {
    condition     = length(output.params_get) == 5
    error_message = "Expected 5 SSM parameters to fetch"
  }

  assert {
    condition     = contains(output.params_get, "/homelab/infrastructure/accounts/unifi/api-key")
    error_message = "params_get should include unifi api key path"
  }

  assert {
    condition     = contains(output.params_get, "/homelab/infrastructure/accounts/github/token")
    error_message = "params_get should include github token path"
  }
}

# Base tests for config module - validates core output structure and transformations

variables {
  name     = "test-cluster"
  features = ["gateway-api", "longhorn", "prometheus", "spegel"]

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
    timeservers         = ["0.pool.ntp.org", "1.pool.ntp.org"]
  }

  machines = {
    node1 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = {
        selector     = "disk.model = *"
        architecture = "amd64"
        platform     = "metal"
      }
      volumes = [{
        name     = "longhorn"
        selector = "system_disk == true"
        maxSize  = "50%"
        tags     = ["fast", "ssd"]
      }]
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
        addresses          = ["192.168.10.101"]
      }]
    }
    node2 = {
      cluster = "test-cluster"
      type    = "controlplane"
      install = {
        selector     = "disk.model = *"
        architecture = "amd64"
        platform     = "metal"
      }
      volumes = [{
        name     = "data"
        selector = "disk.dev_path == '/dev/sda'"
        maxSize  = "100%"
        tags     = ["fast", "ssd"]
      }]
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
        addresses          = ["192.168.10.102"]
      }]
    }
    node3 = {
      cluster = "other-cluster"
      type    = "controlplane"
      install = { selector = "disk.model = *" }
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:03"]
        addresses          = ["192.168.10.103"]
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

  # 2 controlplane records + 2 wildcard ingress records (internal + external)
  assert {
    condition     = length(output.unifi.dns_records) == 4
    error_message = "Expected 4 DNS records (2 controlplane + 2 wildcard ingress)"
  }

  assert {
    condition     = length(output.unifi.dhcp_reservations) == 2
    error_message = "Expected 2 DHCP reservations (one per machine)"
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

  assert {
    condition     = length(output.talos.bootstrap_charts) == 1
    error_message = "Expected 1 bootstrap chart (cilium)"
  }

  assert {
    condition     = output.talos.bootstrap_charts[0].name == "cilium"
    error_message = "Bootstrap chart should be cilium"
  }

  assert {
    condition     = output.talos.bootstrap_charts[0].repository == "https://helm.cilium.io/"
    error_message = "Cilium repository should be https://helm.cilium.io/"
  }

  assert {
    condition     = output.talos.bootstrap_charts[0].version == "1.16.0"
    error_message = "Cilium version should match versions.cilium"
  }

  assert {
    condition     = output.talos.bootstrap_charts[0].namespace == "kube-system"
    error_message = "Cilium namespace should be kube-system"
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

# Cluster environment variables for flux post-build substitution (split into cluster_vars and version_vars)
run "cluster_vars_content" {
  command = plan

  assert {
    condition     = length(output.cluster_vars) >= 14
    error_message = "Expected at least 14 cluster vars (non-version)"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "cluster_name" && v.value == "test-cluster"
    ])
    error_message = "cluster_name env var should be set"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "cluster_tld" && v.value == "internal.test.local"
    ])
    error_message = "cluster_tld env var should match internal_tld"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "cluster_vip" && v.value == "192.168.10.20"
    ])
    error_message = "cluster_vip env var should match networking.vip"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "cluster_pod_subnet" && v.value == "172.18.0.0/16"
    ])
    error_message = "cluster_pod_subnet env var should match networking.pod_subnet"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "cluster_id" && v.value == "1"
    ])
    error_message = "cluster_id env var should match networking.id"
  }

  # tls_issuer should be present (defaults to cloudflare for unknown clusters)
  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "tls_issuer" && v.value == "cloudflare"
    ])
    error_message = "tls_issuer env var should default to cloudflare for unknown clusters"
  }

  # GitHub org and repository for Flux notification dispatch
  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "github_org" && v.value == "testorg"
    ])
    error_message = "github_org env var should match accounts.github.org"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "github_repository" && v.value == "testrepo"
    ])
    error_message = "github_repository env var should match accounts.github.repository"
  }
}

# TLS issuer configuration per cluster type
run "tls_issuer_dev_cluster" {
  command = plan

  variables {
    name = "dev"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "tls_issuer" && v.value == "homelab-ca"
    ])
    error_message = "Dev cluster should use homelab-ca issuer to avoid Let's Encrypt rate limits"
  }
}

run "tls_issuer_integration_cluster" {
  command = plan

  variables {
    name = "integration"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "tls_issuer" && v.value == "homelab-ca"
    ])
    error_message = "Integration cluster should use homelab-ca issuer to avoid Let's Encrypt rate limits"
  }
}

run "tls_issuer_live_cluster" {
  command = plan

  variables {
    name = "live"
  }

  assert {
    condition = anytrue([
      for v in output.cluster_vars : v.name == "tls_issuer" && v.value == "cloudflare"
    ])
    error_message = "Live cluster should use cloudflare issuer for browser-trusted certificates"
  }
}

# Talos 1.12 configs array structure
run "talos_configs_array_structure" {
  command = plan

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      length(m.configs) >= 4
    ])
    error_message = "Each machine should have at least 4 config documents (main, hostname, link_alias, bond, dhcp)"
  }

  # First config should be the main machine config
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(m.configs[0], "clusterName: test-cluster")
    ])
    error_message = "First config document should be main machine config with cluster name"
  }

  # HostnameConfig document should be present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      anytrue([for c in m.configs : strcontains(c, "kind: HostnameConfig")])
    ])
    error_message = "HostnameConfig document should be present in configs"
  }

  # ResolverConfig document should be present (nameservers)
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      anytrue([for c in m.configs : strcontains(c, "kind: ResolverConfig")])
    ])
    error_message = "ResolverConfig document should be present in configs"
  }

  # TimeSyncConfig document should be present (timeservers)
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      anytrue([for c in m.configs : strcontains(c, "kind: TimeSyncConfig")])
    ])
    error_message = "TimeSyncConfig document should be present in configs"
  }
}

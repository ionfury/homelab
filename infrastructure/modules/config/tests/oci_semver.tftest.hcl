# Tests for OCI semver configuration - validates cluster-specific artifact selection logic

# Base variables shared across all tests
variables {
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

  cilium_values_template = <<-EOT
    cluster:
      name: $${cluster_name}
  EOT
}

# Dev cluster uses git sync - empty OCI config
run "dev_cluster_oci_config" {
  command = plan

  variables {
    name = "dev"

    machines = {
      node1 = {
        cluster = "dev"
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
    condition     = output.bootstrap.source_type == "git"
    error_message = "Dev cluster should use git source type"
  }

  assert {
    condition     = output.bootstrap.oci_url == ""
    error_message = "Dev cluster should have empty oci_url (uses git sync)"
  }

  assert {
    condition     = output.bootstrap.oci_tag_pattern == ""
    error_message = "Dev cluster should have empty oci_tag_pattern (uses git sync)"
  }

  assert {
    condition     = output.bootstrap.oci_semver == ""
    error_message = "Dev cluster should have empty oci_semver (uses git sync)"
  }
}

# Integration cluster accepts pre-release versions (rc builds)
run "integration_cluster_oci_config" {
  command = plan

  variables {
    name = "integration"

    machines = {
      node1 = {
        cluster = "integration"
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
    condition     = output.bootstrap.source_type == "oci"
    error_message = "Integration cluster should use oci source type"
  }

  assert {
    condition     = output.bootstrap.oci_url == "oci://ghcr.io/testorg/testrepo/platform"
    error_message = "Integration cluster should have oci_url pointing to GHCR"
  }

  assert {
    condition     = output.bootstrap.oci_tag_pattern == "latest"
    error_message = "Integration cluster should use 'latest' tag pattern"
  }

  assert {
    condition     = output.bootstrap.oci_semver == ">= 0.0.0-0"
    error_message = "Integration cluster should have oci_semver '>= 0.0.0-0' to accept pre-releases"
  }
}

# Live cluster uses stable releases only
run "live_cluster_oci_config" {
  command = plan

  variables {
    name = "live"

    machines = {
      node1 = {
        cluster = "live"
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
    condition     = output.bootstrap.source_type == "oci"
    error_message = "Live cluster should use oci source type"
  }

  assert {
    condition     = output.bootstrap.oci_url == "oci://ghcr.io/testorg/testrepo/platform"
    error_message = "Live cluster should have oci_url pointing to GHCR"
  }

  assert {
    condition     = output.bootstrap.oci_tag_pattern == "validated-*"
    error_message = "Live cluster should use 'validated-*' tag pattern for promoted artifacts"
  }

  assert {
    condition     = output.bootstrap.oci_semver == ">= 0.0.0"
    error_message = "Live cluster should have oci_semver '>= 0.0.0' for stable releases"
  }
}

# Unknown cluster defaults to dev behavior (empty config)
run "unknown_cluster_oci_config" {
  command = plan

  variables {
    name = "staging"

    machines = {
      node1 = {
        cluster = "staging"
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
    condition     = output.bootstrap.source_type == "git"
    error_message = "Unknown cluster should default to git source type (same as dev)"
  }

  assert {
    condition     = output.bootstrap.oci_url == ""
    error_message = "Unknown cluster should have empty oci_url (same as dev)"
  }

  assert {
    condition     = output.bootstrap.oci_tag_pattern == ""
    error_message = "Unknown cluster should have empty oci_tag_pattern (same as dev)"
  }

  assert {
    condition     = output.bootstrap.oci_semver == ""
    error_message = "Unknown cluster should default to empty oci_semver (same as dev)"
  }
}

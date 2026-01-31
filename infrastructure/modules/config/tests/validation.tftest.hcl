# Validation tests for config module - validates input constraints and edge cases

variables {
  name = "validation-test"

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

  machines = {
    node1 = {
      cluster = "validation-test"
      type    = "controlplane"
      install = { selector = "disk.model = *" }
      bonds = [{
        link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
        addresses          = ["192.168.10.101"]
      }]
    }
  }
}

# Feature validation - valid features
run "valid_features_all" {
  command = plan

  variables {
    features = ["gateway-api", "longhorn", "prometheus", "spegel"]
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "All valid features should be accepted"
  }
}

run "valid_features_subset" {
  command = plan

  variables {
    features = ["longhorn", "prometheus"]
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Feature subset should be accepted"
  }
}

run "valid_features_single" {
  command = plan

  variables {
    features = ["gateway-api"]
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Single feature should be accepted"
  }
}

run "valid_features_empty" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Empty features should be accepted"
  }
}

# Version validation - different valid formats
run "valid_versions_with_v_prefix" {
  command = plan

  variables {
    versions = {
      talos       = "v1.10.0"
      kubernetes  = "1.33.0"
      cilium      = "1.17.0"
      gateway_api = "v1.3.0"
      flux        = "v2.5.0"
      prometheus  = "21.0.0"
    }
  }

  assert {
    condition     = output.talos.talos_version == "v1.10.0"
    error_message = "Talos version should be set"
  }
}

run "valid_versions_with_prerelease" {
  command = plan

  variables {
    versions = {
      talos       = "v1.9.0-alpha.1"
      kubernetes  = "1.32.0-rc.1"
      cilium      = "1.16.0-beta.2"
      gateway_api = "v1.2.0-alpha"
      flux        = "v2.4.0-rc1"
      prometheus  = "20.0.0-beta"
    }
  }

  assert {
    condition     = output.talos.talos_version == "v1.9.0-alpha.1"
    error_message = "Prerelease versions should be accepted"
  }
}

# Network CIDR validation - different valid subnets
run "valid_cidr_large_subnet" {
  command = plan

  variables {
    networking = {
      id                  = 1
      internal_tld        = "internal.test.local"
      external_tld        = "external.test.local"
      node_subnet         = "10.0.0.0/8"
      pod_subnet          = "172.16.0.0/12"
      service_subnet      = "192.168.0.0/16"
      vip                 = "10.0.0.100"
      ip_pool_start       = "10.0.0.101"
      internal_ingress_ip = "10.0.0.102"
      external_ingress_ip = "10.0.0.103"
      ip_pool_stop        = "10.0.0.200"
      bgp_asn             = 64513
      nameservers         = ["8.8.8.8"]
      timeservers         = ["time.google.com"]
    }
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Large CIDR subnets should be accepted"
  }
}

run "valid_cidr_small_subnet" {
  command = plan

  variables {
    networking = {
      id                  = 1
      internal_tld        = "internal.test.local"
      external_tld        = "external.test.local"
      node_subnet         = "192.168.100.0/28"
      pod_subnet          = "10.244.0.0/16"
      service_subnet      = "10.96.0.0/16"
      vip                 = "192.168.100.1"
      ip_pool_start       = "192.168.100.2"
      internal_ingress_ip = "192.168.100.3"
      external_ingress_ip = "192.168.100.4"
      ip_pool_stop        = "192.168.100.14"
      bgp_asn             = 64513
      nameservers         = ["192.168.100.1"]
      timeservers         = ["pool.ntp.org"]
    }
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Small CIDR subnets should be accepted"
  }
}

# Domain validation - different valid formats
run "valid_domain_simple" {
  command = plan

  variables {
    networking = {
      id                  = 1
      internal_tld        = "local"
      external_tld        = "example.com"
      node_subnet         = "192.168.10.0/24"
      pod_subnet          = "172.18.0.0/16"
      service_subnet      = "172.19.0.0/16"
      vip                 = "192.168.10.20"
      ip_pool_start       = "192.168.10.21"
      internal_ingress_ip = "192.168.10.22"
      external_ingress_ip = "192.168.10.23"
      ip_pool_stop        = "192.168.10.29"
      bgp_asn             = 64513
      bgp_asn             = 64513
      nameservers         = ["192.168.10.1"]
      timeservers         = ["0.pool.ntp.org"]
    }
  }

  assert {
    condition     = output.cluster_endpoint == "k8s.local"
    error_message = "Simple domain should be accepted"
  }
}

run "valid_domain_subdomain" {
  command = plan

  variables {
    networking = {
      id                  = 1
      internal_tld        = "k8s.internal.company.corp"
      external_tld        = "apps.external.company.com"
      node_subnet         = "192.168.10.0/24"
      pod_subnet          = "172.18.0.0/16"
      service_subnet      = "172.19.0.0/16"
      vip                 = "192.168.10.20"
      ip_pool_start       = "192.168.10.21"
      internal_ingress_ip = "192.168.10.22"
      external_ingress_ip = "192.168.10.23"
      ip_pool_stop        = "192.168.10.29"
      bgp_asn             = 64513
      bgp_asn             = 64513
      nameservers         = ["192.168.10.1"]
      timeservers         = ["0.pool.ntp.org"]
    }
  }

  assert {
    condition     = output.cluster_endpoint == "k8s.k8s.internal.company.corp"
    error_message = "Nested subdomain should be accepted"
  }
}

# Nameserver validation
run "valid_nameservers_multiple" {
  command = plan

  variables {
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
      bgp_asn             = 64513
      nameservers         = ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
      timeservers         = ["0.pool.ntp.org"]
    }
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Multiple nameservers should be accepted"
  }
}

# Timeserver validation
run "valid_timeservers_multiple" {
  command = plan

  variables {
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
      bgp_asn             = 64513
      nameservers         = ["192.168.10.1"]
      timeservers         = ["0.pool.ntp.org", "1.pool.ntp.org", "time.google.com", "time.cloudflare.com"]
    }
  }

  assert {
    condition     = length(output.machines) >= 0
    error_message = "Multiple timeservers should be accepted"
  }
}

# Local paths validation
run "valid_local_paths_custom" {
  command = plan

  variables {
    local_paths = {
      talos      = "/opt/talos/config"
      kubernetes = "/opt/kubernetes/config"
    }
  }

  assert {
    condition     = output.talos.talos_config_path == "/opt/talos/config"
    error_message = "Custom talos path should be used"
  }

  assert {
    condition     = output.talos.kubernetes_config_path == "/opt/kubernetes/config"
    error_message = "Custom kubernetes path should be used"
  }
}

# SSM output path validation
run "valid_ssm_output_path_custom" {
  command = plan

  variables {
    ssm_output_path = "/custom/ssm/path"
  }

  assert {
    condition     = strcontains(output.aws_set_params.kubeconfig_path, "/custom/ssm/path")
    error_message = "Custom SSM output path should be used"
  }
}

# Machine type validation
run "valid_machine_types" {
  command = plan

  variables {
    machines = {
      cp1 = {
        cluster = "validation-test"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
      worker1 = {
        cluster = "validation-test"
        type    = "worker"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines) == 2
    error_message = "Both controlplane and worker types should be valid"
  }
}

# Architecture validation
run "valid_architectures" {
  command = plan

  variables {
    machines = {
      amd64node = {
        cluster = "validation-test"
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
      arm64node = {
        cluster = "validation-test"
        type    = "worker"
        install = {
          selector     = "disk.model = *"
          architecture = "arm64"
          sbc          = "rpi_generic"
        }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.102"]
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines) == 2
    error_message = "Both amd64 and arm64 architectures should be valid"
  }
}

# Bonds validation - multi-link bond
run "valid_multi_link_bond" {
  command = plan

  variables {
    machines = {
      node1 = {
        cluster = "validation-test"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01", "aa:bb:cc:dd:ee:02"]
          addresses          = ["192.168.10.101"]
          mode               = "802.3ad"
          mtu                = 9000
        }]
      }
    }
  }

  assert {
    condition     = length(output.machines) == 1
    error_message = "Multi-link bond should be valid"
  }
}

# Bonds validation - multiple bonds
run "valid_multiple_bonds" {
  command = plan

  variables {
    machines = {
      node1 = {
        cluster = "validation-test"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        bonds = [
          {
            link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
            addresses          = ["192.168.10.101"]
          },
          {
            link_permanentAddr = ["aa:bb:cc:dd:ee:02"]
            addresses          = ["10.0.0.101"]
          }
        ]
      }
    }
  }

  assert {
    condition     = length(output.machines) == 1
    error_message = "Multiple bonds should be valid"
  }
}

# Volumes validation
run "valid_volumes" {
  command = plan

  variables {
    machines = {
      node1 = {
        cluster = "validation-test"
        type    = "controlplane"
        install = { selector = "disk.model = *" }
        volumes = [
          {
            name     = "system"
            selector = "system_disk == true"
            maxSize  = "50%"
            tags     = ["fast", "nvme"]
          },
          {
            name     = "data"
            selector = "disk.dev_path == '/dev/sdb'"
            maxSize  = "100%"
            tags     = ["slow", "hdd"]
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
    condition     = length(output.machines) == 1
    error_message = "Multiple volumes should be valid"
  }
}

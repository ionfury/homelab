# Thread IPv6 feature tests - validates IPv6 RA sysctls for OTBR Route Information
# Option consumption (Thread OMR prefix), and coexistence with hugepages sysctls

variables {
  name = "test-cluster"

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

# Flag absent → no IPv6 sysctls emitted
run "thread_ipv6_absent_no_sysctls" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for name, m in output.machines :
      length(m.sysctls) == 0
    ])
    error_message = "Nodes should have no sysctls when thread-ipv6 is not enabled"
  }
}

# Flag present → all six sysctls emitted with correct string values
run "thread_ipv6_enabled_emits_sysctls" {
  command = plan

  variables {
    features = ["thread-ipv6"]
  }

  assert {
    condition     = output.machines["node1"].sysctls["net.ipv6.conf.all.disable_ipv6"] == "0"
    error_message = "thread-ipv6 should set net.ipv6.conf.all.disable_ipv6 = 0"
  }

  assert {
    condition     = output.machines["node1"].sysctls["net.ipv6.conf.default.disable_ipv6"] == "0"
    error_message = "thread-ipv6 should set net.ipv6.conf.default.disable_ipv6 = 0"
  }

  assert {
    condition     = output.machines["node1"].sysctls["net.ipv6.conf.all.accept_ra"] == "2"
    error_message = "thread-ipv6 should set net.ipv6.conf.all.accept_ra = 2"
  }

  assert {
    condition     = output.machines["node1"].sysctls["net.ipv6.conf.default.accept_ra"] == "2"
    error_message = "thread-ipv6 should set net.ipv6.conf.default.accept_ra = 2"
  }

  assert {
    condition     = output.machines["node1"].sysctls["net.ipv6.conf.all.accept_ra_rt_info_max_plen"] == "64"
    error_message = "thread-ipv6 should set net.ipv6.conf.all.accept_ra_rt_info_max_plen = 64"
  }

  assert {
    condition     = output.machines["node1"].sysctls["net.ipv6.conf.default.accept_ra_rt_info_max_plen"] == "64"
    error_message = "thread-ipv6 should set net.ipv6.conf.default.accept_ra_rt_info_max_plen = 64"
  }

  assert {
    condition     = length(output.machines["node1"].sysctls) == 6
    error_message = "thread-ipv6 should emit exactly six sysctls when no other sysctl feature is active"
  }
}

# Flag present alongside 2M hugepages → seven entries total, vm.nr_hugepages preserved
run "thread_ipv6_coexists_with_hugepages" {
  command = plan

  variables {
    features = ["thread-ipv6"]
    machines = {
      hp-node = {
        cluster = "test-cluster"
        type    = "controlplane"
        features = {
          hugepages = { size = "2M", count = 512 }
        }
        install = { selector = "disk.model = *" }
        bonds = [{
          link_permanentAddr = ["aa:bb:cc:dd:ee:01"]
          addresses          = ["192.168.10.101"]
        }]
      }
    }
  }

  assert {
    condition     = output.machines["hp-node"].sysctls["vm.nr_hugepages"] == "512"
    error_message = "thread-ipv6 must not clobber vm.nr_hugepages"
  }

  assert {
    condition     = output.machines["hp-node"].sysctls["net.ipv6.conf.all.accept_ra_rt_info_max_plen"] == "64"
    error_message = "thread-ipv6 should still set accept_ra_rt_info_max_plen alongside hugepages"
  }

  assert {
    condition     = length(output.machines["hp-node"].sysctls) == 7
    error_message = "hugepages + thread-ipv6 should emit seven total sysctls"
  }
}

# Flag present → rendered in Talos machine YAML
run "thread_ipv6_in_talos_yaml" {
  command = plan

  variables {
    features = ["thread-ipv6"]
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "sysctls:")
    ])
    error_message = "Talos config should contain sysctls: section"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.configs), "net.ipv6.conf.all.accept_ra_rt_info_max_plen: \"64\"")
    ])
    error_message = "Talos config should contain accept_ra_rt_info_max_plen sysctl"
  }
}

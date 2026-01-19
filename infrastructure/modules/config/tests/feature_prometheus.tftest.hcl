# Prometheus feature tests - validates metrics scraping configuration

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

# With prometheus enabled - etcd metrics endpoint exposed
run "prometheus_etcd_extra_args" {
  command = plan

  variables {
    features = ["prometheus"]
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "listen-metrics-urls")
    ])
    error_message = "etcd listen-metrics-urls should be in config when prometheus enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "http://0.0.0.0:2381")
    ])
    error_message = "etcd metrics should listen on 0.0.0.0:2381"
  }
}

# Controller manager bind address for prometheus scraping
run "prometheus_controller_manager_extra_args" {
  command = plan

  variables {
    features = ["prometheus"]
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "controllerManager:")
    ])
    error_message = "controllerManager section should be in config when prometheus enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "bind-address") &&
      strcontains(join("\n", m.config_patches), "0.0.0.0")
    ])
    error_message = "bind-address should be 0.0.0.0 for controller manager metrics"
  }
}

# Scheduler bind address for prometheus scraping
run "prometheus_scheduler_extra_args" {
  command = plan

  variables {
    features = ["prometheus"]
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "scheduler:")
    ])
    error_message = "scheduler section should be in config when prometheus enabled"
  }
}

# Prometheus CRD extraManifests
run "prometheus_extra_manifests" {
  command = plan

  variables {
    features = ["prometheus"]
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "extraManifests:")
    ])
    error_message = "extraManifests section should be present when prometheus enabled"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "crd-podmonitors.yaml")
    ])
    error_message = "PodMonitor CRD should be in extraManifests"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "crd-servicemonitors.yaml")
    ])
    error_message = "ServiceMonitor CRD should be in extraManifests"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "crd-probes.yaml")
    ])
    error_message = "Probes CRD should be in extraManifests"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "crd-prometheusrules.yaml")
    ])
    error_message = "PrometheusRules CRD should be in extraManifests"
  }
}

# Prometheus version in manifest URLs
run "prometheus_version_in_manifests" {
  command = plan

  variables {
    features = ["prometheus"]
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "prometheus-operator-crds-20.0.0")
    ])
    error_message = "Prometheus version 20.0.0 should be in manifest URLs"
  }
}

# Different prometheus version
run "prometheus_custom_version" {
  command = plan

  variables {
    features = ["prometheus"]
    versions = {
      talos       = "v1.9.0"
      kubernetes  = "1.32.0"
      cilium      = "1.16.0"
      gateway_api = "v1.2.0"
      flux        = "v2.4.0"
      prometheus  = "21.5.0"
    }
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "prometheus-operator-crds-21.5.0")
    ])
    error_message = "Custom prometheus version should be reflected in manifest URLs"
  }
}

# Without prometheus - no etcd extraArgs
run "no_prometheus_no_etcd_args" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "listen-metrics-urls")
    ])
    error_message = "etcd listen-metrics-urls should not be in config without prometheus"
  }
}

# Without prometheus - no controller manager section
run "no_prometheus_no_controller_manager_section" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "controllerManager:")
    ])
    error_message = "controllerManager section should not be in config without prometheus"
  }
}

# Without prometheus - no scheduler section
run "no_prometheus_no_scheduler_section" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "scheduler:")
    ])
    error_message = "scheduler section should not be in config without prometheus"
  }
}

# Without prometheus - no CRD manifests
run "no_prometheus_no_manifests" {
  command = plan

  variables {
    features = []
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      !strcontains(join("\n", m.config_patches), "prometheus-operator-crds")
    ])
    error_message = "Prometheus CRD manifests should not be in config without prometheus"
  }
}

# Prometheus with other features
run "prometheus_with_gateway_api" {
  command = plan

  variables {
    features = ["prometheus", "gateway-api"]
  }

  # Both sets of manifests should be present
  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "prometheus-operator-crds")
    ])
    error_message = "Prometheus manifests should be present with gateway-api"
  }

  assert {
    condition = alltrue([
      for m in output.talos.talos_machines :
      strcontains(join("\n", m.config_patches), "experimental-install.yaml")
    ])
    error_message = "Gateway API manifests should be present with prometheus"
  }
}


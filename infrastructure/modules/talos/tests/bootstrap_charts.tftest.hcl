# Bootstrap chart injection tests for talos module

# Provider v0.11.0 regression: on_destroy.reset/graceful/reboot use bool
# instead of basetypes.BoolValue in the schema, crashing PlanResourceChange
# when any resource input is unknown (talos_machine_secrets not yet applied).
# override_resource skips PlanResourceChange entirely for these resources.
# helm mock_provider is safe (no schema bug) and required for helm data sources.
override_resource {
  target = talos_machine_configuration_apply.machines
  values = {}
}

override_resource {
  target = talos_machine_bootstrap.this
  values = {}
}

override_resource {
  target = talos_cluster_kubeconfig.this
  values = {}
}

override_data {
  target = data.talos_image_factory_extensions_versions.machine_version
  values = {
    extensions_info = []
  }
}

mock_provider "helm" {}

variables {
  talos_version      = "v1.9.0"
  kubernetes_version = "1.32.0"

  talos_machines = [
    {
      install = { selector = "disk.model = *" }
      configs = [
        <<-EOT
        cluster:
          clusterName: chart-test.local
          controlPlane:
            endpoint: https://chart-test.local:6443
        machine:
          type: controlplane
        EOT
        ,
        <<-EOT
        apiVersion: v1alpha1
        kind: HostnameConfig
        hostname: host1
        EOT
        ,
        <<-EOT
        apiVersion: v1alpha1
        kind: BondConfig
        name: bond0
        links:
          - link0_0
        bondMode: active-backup
        mtu: 1500
        addresses:
          - address: 10.10.10.10/24
        EOT
      ]
    }
  ]
}

run "empty_bootstrap_charts" {
  command = plan

  variables {
    bootstrap_charts = []
  }

  assert {
    condition     = length(data.helm_template.bootstrap_charts) == 0
    error_message = "No helm templates should be generated with empty bootstrap_charts"
  }
}

run "single_bootstrap_chart" {
  command = plan

  variables {
    bootstrap_charts = [
      {
        repository = "https://helm.cilium.io/"
        chart      = "cilium"
        name       = "cilium"
        version    = "1.16.0"
        namespace  = "kube-system"
        values     = <<EOT
ipam:
  mode: kubernetes
EOT
      }
    ]
  }

  assert {
    condition     = length(data.helm_template.bootstrap_charts) == 1
    error_message = "Expected 1 helm template for cilium"
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cilium"].repository == "https://helm.cilium.io/"
    error_message = "Cilium repository incorrect"
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cilium"].chart == "cilium"
    error_message = "Cilium chart name incorrect"
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cilium"].version == "1.16.0"
    error_message = "Cilium version incorrect"
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cilium"].namespace == "kube-system"
    error_message = "Cilium namespace incorrect"
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cilium"].kube_version == "1.32.0"
    error_message = "Kubernetes version should be passed to helm template"
  }
}

run "multiple_bootstrap_charts" {
  command = plan

  variables {
    bootstrap_charts = [
      {
        repository = "https://helm.cilium.io/"
        chart      = "cilium"
        name       = "cilium"
        version    = "1.16.0"
        namespace  = "kube-system"
        values     = "ipam:\n  mode: kubernetes"
      },
      {
        repository = "https://charts.jetstack.io"
        chart      = "cert-manager"
        name       = "cert-manager"
        version    = "1.14.0"
        namespace  = "cert-manager"
        values     = "installCRDs: true"
      }
    ]
  }

  assert {
    condition     = length(data.helm_template.bootstrap_charts) == 2
    error_message = "Expected 2 helm templates"
  }

  assert {
    condition     = contains(keys(data.helm_template.bootstrap_charts), "cilium")
    error_message = "Cilium chart should be present"
  }

  assert {
    condition     = contains(keys(data.helm_template.bootstrap_charts), "cert-manager")
    error_message = "Cert-manager chart should be present"
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cert-manager"].namespace == "cert-manager"
    error_message = "Cert-manager namespace incorrect"
  }
}

run "chart_with_complex_values" {
  command = plan

  variables {
    bootstrap_charts = [
      {
        repository = "https://helm.cilium.io/"
        chart      = "cilium"
        name       = "cilium"
        version    = "1.16.0"
        namespace  = "kube-system"
        values     = <<EOT
ipam:
  mode: kubernetes
k8sServiceHost: 127.0.0.1
k8sServicePort: 7445
kubeProxyReplacement: true
securityContext:
  capabilities:
    ciliumAgent:
      - CHOWN
      - KILL
      - NET_ADMIN
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
EOT
      }
    ]
  }

  assert {
    condition     = length(data.helm_template.bootstrap_charts["cilium"].values) == 1
    error_message = "Values should be passed to helm template"
  }
}

run "chart_values_propagated" {
  command = plan

  variables {
    bootstrap_charts = [
      {
        repository = "https://charts.jetstack.io"
        chart      = "cert-manager"
        name       = "cert-manager"
        version    = "1.14.0"
        namespace  = "cert-manager"
        values     = "installCRDs: true"
      }
    ]
  }

  assert {
    condition     = data.helm_template.bootstrap_charts["cert-manager"].name == "cert-manager"
    error_message = "Chart name should be used in template"
  }
}

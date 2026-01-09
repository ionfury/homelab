# Bootstrap chart injection tests for talos module

variables {
  talos_version      = "v1.9.0"
  kubernetes_version = "1.32.0"

  talos_machines = [
    {
      install = { selector = "disk.model = *" }
      config  = <<EOT
cluster:
  clusterName: chart-test.local
  controlPlane:
    endpoint: https://chart-test.local:6443
machine:
  type: controlplane
  network:
    hostname: host1
    interfaces:
      - addresses:
        - 10.10.10.10/24
EOT
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

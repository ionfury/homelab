locals {
  github_repository_cluster_directory = "${var.github.repository_path}/${var.cluster_name}"
}

data "github_repository" "this" {
  full_name = "${var.github.org}/${var.github.repository}"
}

resource "github_repository_file" "this" {
  repository = data.github_repository.this.name
  file       = "${local.github_repository_cluster_directory}/generated-cluster-vars.env"
  content = templatefile("${path.module}/resources/generated-cluster-vars.env.tftpl", {
    cluster_vars = var.cluster_env_vars
  })
  overwrite_on_create = true
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

resource "kubernetes_secret" "git_auth" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "flux-system"
    namespace = "flux-system"
  }

  data = {
    username = "git"
    password = var.github.token
  }

  type = "Opaque"
}

resource "helm_release" "flux_operator" {
  depends_on = [kubernetes_namespace.flux_system, data.github_repository.this, github_repository_file.this]

  name       = "flux-operator"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  wait       = true
}

resource "helm_release" "flux_instance" {
  depends_on = [helm_release.flux_operator]

  name       = "flux"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  wait       = true

  values = [
    templatefile("${path.module}/resources/instance.yaml.tftpl", {
      cluster_name           = var.cluster_name
      github_org             = var.github.org
      github_repository      = var.github.repository
      github_repository_path = var.github.repository_path
      flux_version           = var.flux_version
    })
  ]
}


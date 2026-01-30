locals {
  github_repository_cluster_directory = "${var.github.repository_path}/${var.cluster_name}"
}

data "github_repository" "this" {
  full_name = "${var.github.org}/${var.github.repository}"
}

resource "github_repository_file" "cluster_vars" {
  repository          = data.github_repository.this.name
  file                = "${local.github_repository_cluster_directory}/.cluster-vars.env"
  content             = templatefile("${path.module}/resources/cluster-vars.env.tftpl", { cluster_vars = var.cluster_vars })
  overwrite_on_create = true
}

resource "github_repository_file" "versions" {
  repository          = data.github_repository.this.name
  file                = "${local.github_repository_cluster_directory}/.versions.env"
  content             = templatefile("${path.module}/resources/versions.env.tftpl", { version_vars = var.version_vars })
  overwrite_on_create = true
}


resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [metadata]
  }

  timeouts {
    delete = "5m"
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
    password = data.aws_ssm_parameter.github_token.value
  }

  type = "Opaque"
}

resource "helm_release" "flux_operator" {
  depends_on = [
    kubernetes_namespace.flux_system,
    data.github_repository.this,
    github_repository_file.cluster_vars,
    github_repository_file.versions,
  ]

  name       = "flux-operator"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  wait       = true
  timeout    = 300
}

resource "helm_release" "flux_instance" {
  depends_on = [helm_release.flux_operator]

  name       = "flux"
  namespace  = "flux-system"
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"
  wait       = true
  timeout    = 300

  values = [
    var.source_type == "git" ? templatefile("${path.module}/resources/instance.yaml.tftpl", {
      cluster_name           = var.cluster_name
      github_org             = var.github.org
      github_repository      = var.github.repository
      github_repository_path = var.github.repository_path
      flux_version           = var.flux_version
      }) : templatefile("${path.module}/resources/instance-oci.yaml.tftpl", {
      cluster_name = var.cluster_name
      oci_url      = var.oci_url
      oci_semver   = var.oci_semver
      flux_version = var.flux_version
    })
  ]
}


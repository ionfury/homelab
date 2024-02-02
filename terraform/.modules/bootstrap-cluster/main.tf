resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "kubernetes_secret" "access_key" {
  depends_on = [kubernetes_namespace.flux_system]
  metadata {
    name      = "external-secrets-access-key"
    namespace = "kube-system"
  }

  data = {
    access_key        = "${var.external_secrets_access_key_id}"
    secret_access_key = "${var.external_secrets_access_key_secret}"
  }
}

resource "kubernetes_secret" "ssh_key" {
  depends_on = [kubernetes_namespace.flux_system]
  metadata {
    name      = "flux-ssh-key"
    namespace = "flux-system"
  }

  data = {
    identity       = "${var.github_ssh_key}"
    "identity.pub" = "${var.github_ssh_pub}"
    known_hosts    = "${var.known_hosts}"
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on             = [kubernetes_secret.ssh_key]
  path                   = "clusters/${var.cluster_name}"
  kustomization_override = file("${path.module}/manifests/kustomization.yaml")

  components_extra = [
    "image-reflector-controller",
    "image-automation-controller"
  ]
}


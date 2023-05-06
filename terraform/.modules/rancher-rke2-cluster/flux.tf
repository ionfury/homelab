provider "flux" {
  kubernetes = {
    config_path = local_file.kubeconfig.filename
  }
  git = {
    url          = "${var.github_url}"
    author_email = "flux@tomnowak.work"
    author_name  = "flux"
    branch       = "main"
    ssh = {
      username    = "git"
      private_key = "${var.github_ssh_key}"
    }
  }
}

provider "kubernetes" {
  config_path = local_file.kubeconfig.filename
}

resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }
}

resource "flux_bootstrap_git" "this" {
  depends_on             = [kubernetes_secret.sops_key, kubernetes_secret.ssh_key]
  path                   = "clusters/${var.name}"
  kustomization_override = file("${path.module}/manifests/kustomization.yaml")

  components_extra = [
    "image-reflector-controller",
    "image-automation-controller"
  ]
}

resource "kubernetes_secret" "sops_key" {
  depends_on = [kubernetes_namespace.flux_system]
  metadata {
    name      = "sops-key"
    namespace = "flux-system"
  }

  data = {
    "age.encrypted.agekey" = "blank"
  }
}


resource "kubernetes_secret" "access_key" {
  depends_on = [kubernetes_namespace.flux_system]
  metadata {
    name      = "external-secrets-access-key"
    namespace = "kube-system"
  }

  data = {
    access_key        = "${aws_iam_access_key.this.id}"
    secret_access_key = "${aws_iam_access_key.this.secret}"
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
    "identity.pub" = "${var.github_ssh_key}"
    known_hosts    = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
  }
}

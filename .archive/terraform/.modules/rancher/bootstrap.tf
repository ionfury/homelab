
resource "random_password" "rancher_bootstrap_password" {
  length  = 24
  special = false
}

resource "helm_release" "rancher" {
  depends_on = [helm_release.cert_manager]
  name       = "rancher"
  namespace  = "cattle-system"
  chart      = "rancher"
  version    = var.rancher_version
  repository = "https://releases.rancher.com/server-charts/stable"

  wait             = true
  create_namespace = true
  force_update     = true
  replace          = true

  set {
    name  = "hostname"
    value = join(".", [var.network_subdomain, var.network_tld])
  }
  set {
    name  = "bootstrapPassword"
    value = random_password.rancher_bootstrap_password.result
  }
  set {
    name  = "ingress.tls.source"
    value = "secret"
  }
  set {
    name  = "ingress.extraAnnotations.cert-manager\\.io/cluster-issuer"
    value = "cloudflare"
  }
}

resource "rancher2_bootstrap" "admin" {
  depends_on       = [helm_release.rancher, kubectl_manifest.cloudflare_issuer]
  initial_password = random_password.rancher_bootstrap_password.result
  password         = random_password.rancher_bootstrap_password.result
  telemetry        = false
}

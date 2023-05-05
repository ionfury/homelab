provider "helm" {
  kubernetes {
    host = var.api_server_url
    client_certificate = var.cluster_client_cert
    client_key = var.cluster_client_key
    cluster_ca_certificate = var.cluster_ca_certificate
  }
}

provider "kubectl" {
  host = var.api_server_url
  client_certificate = var.cluster_client_cert
  client_key = var.cluster_client_key
  cluster_ca_certificate = var.cluster_ca_certificate
}

resource "helm_release" "cert_manager" {
  name = "cert-manager"
  namespace = "cert-manager"
  chart      = "cert-manager"
  version    = "1.11.0"
  repository = "https://charts.jetstack.io"

  wait             = true
  create_namespace = true
  force_update     = true
  replace          = true

  set {
    name  = "installCRDs"
    value = true
  }
  set {
    name = "prometheus.enabled"
    value = false
  }
}

data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "dns_tls_edit" {
  name = "rancher-dns-tls-edit"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
      data.cloudflare_api_token_permission_groups.all.zone["SSL and Certificates Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }
}

resource "kubectl_manifest" "cloudflare_secret" {
  yaml_body = <<YAML
apiVersion: v1
data:
  api-token: ${base64encode(cloudflare_api_token.dns_tls_edit.value)}
kind: Secret
metadata:
  name: cloudflare-api-token
  namespace: cert-manager
type: Opaque
YAML
}

resource "kubectl_manifest" "cloudflare_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare
spec:
  acme:
    email: "${var.letsencrypt_issuer}"
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        cloudflare:
          email: "${var.letsencrypt_issuer}"
          apiTokenSecretRef:
            name: cloudflare-api-token
            key: api-token
YAML
}

resource "random_password" "rancher_bootstrap_password" {
  length = 24
  special = false
}

resource "helm_release" "rancher" {
  depends_on = [helm_release.cert_manager]
  name = "rancher"
  namespace = "cattle-system"
  chart = "rancher"
  version = "2.7.1"
  repository = "https://releases.rancher.com/server-charts/stable"

  wait             = true
  create_namespace = true
  force_update     = true
  replace          = true

  set {
    name = "hostname"
    value = "${var.rancher_domain_prefix}.${var.cloudflare_domain}"
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
    name = "ingress.extraAnnotations.cert-manager\\.io/cluster-issuer"
    value = "cloudflare"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = "cert-manager"
  chart      = "cert-manager"
  version    = var.cert_manager_version
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
    name  = "prometheus.enabled"
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
  depends_on = [helm_release.cert_manager, kubectl_manifest.cloudflare_secret]
  yaml_body  = <<YAML
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

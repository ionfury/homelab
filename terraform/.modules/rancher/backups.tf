
/*
resource "helm_release" "rancher_backup_crd" {
  depends_on = [helm_release.rancher]
  name = "rancher-backup-crd"
  namespace = "cattle-resources-system"
  create_namespace = true

  chart = "rancher-backup-crd"
  version = "3.1.0"
  repository = "https://charts.rancher.io"
}

resource "helm_release" "rancher_backup" {
  depends_on = [helm_release.rancher_backup_crd]
  name = "rancher-backup"
  namespace = "cattle-resources-system"

  chart = "rancher-backup"
  version = "3.1.0"
  repository = "https://charts.rancher.io"

  set {
    name = "s3.enabled"
    value = "true"
  }
  set {
    name = "s3.credentialSecretName"
    value = ""
  }
  set {
    name = "s3.credentialSecretNamespace"
    value = ""
  }
  set {
    name = "s3.region"
    value = "us-east-2"
  }
  set {
    name = "s3.bucketName"
    value = "homelab-rancher-backup"
  }
  set {
    name = "s3.endpoint"
    value = "s3.us-east-2.amazonaws.com"
  }
}

resource "kubectl_manifest" "cloudflare_issuer" {
  depends_on = [helm_release.cert_manager]
  yaml_body = <<YAML
apiVersion: resources.cattle.io/v1
kind: Backup
metadata:
  name: s3-recurring-backup
spec:
  storageLocation:
    s3:
      credentialSecretName: s3-creds
      credentialSecretNamespace: default
      bucketName: rancher-backups
      folder: rancher
      region: us-west-2
      endpoint: s3.us-west-2.amazonaws.com
  resourceSetName: rancher-resource-set
  encryptionConfigSecretName: encryptionconfig
  schedule: "@every 7d"
  retentionCount: 3
YAML
}
*/

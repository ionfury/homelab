resource "harvester_storageclass" "storage" {
  for_each = var.harvester.storage

  name       = each.value.name
  is_default = each.value.is_default

  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = 1
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = each.value.selector
  }
}

resource "harvester_storageclass" "storage_backup" {
  for_each = var.harvester.storage

  name       = "${each.value.name}-backup"
  is_default = false

  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = 1
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = each.value.selector
    "recurringJobSelector" = jsonencode(
      [
        {
          isGroup = true
          name    = "weekly"
        },
      ]
    )
  }
}

resource "kubectl_manifest" "daily_longhorn_snapshot" {
  yaml_body = <<YAML
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: daily-snapshot
  namespace: longhorn-system
spec:
  concurrency: 3
  cron: 0 0 * * *
  groups:
  - weekly
  labels: {}
  name: daily-snapshot
  retain: 3
  task: snapshot
YAML
}

resource "kubectl_manifest" "weekly_longhorn_backup" {
  yaml_body = <<YAML
apiVersion: longhorn.io/v1beta2
kind: RecurringJob
metadata:
  name: weekly-backup
  namespace: longhorn-system
spec:
  concurrency: 1
  cron: 0 0 * * 0
  groups:
  - weekly
  labels: {}
  name: weekly-backup
  retain: 3
  task: backup
YAML
}

resource "harvester_storageclass" "fast" {
  name = "fast"
  # Bug in terraform provider, you might need to set this manually
  is_default = true
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = min(var.harvester_node_count, 3)
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = "ssd"
  }
}

resource "harvester_storageclass" "fast_backup" {
  name = "fast-backup"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = min(var.harvester_node_count, 3)
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = "ssd"
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

resource "harvester_storageclass" "slow" {
  name = "slow"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = 1
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = "hdd"
  }
}

resource "harvester_storageclass" "slow_backup" {
  name = "slow-backup"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = 1
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = "hdd"
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

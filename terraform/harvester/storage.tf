resource "harvester_storageclass" "fast" {
  name = "fast"
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
          name    = "nightly"
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
          name    = "nightly"
        },
      ]
    )
  }
}

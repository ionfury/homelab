resource "harvester_storageclass" "longhorn" {
  name = "longhorn"
  parameters = {
    "migratable"          = "true"
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "disabled"
    "fromBackup"          = ""
    "fsType"              = "ext4"
    "numberOfReplicas"    = "3"
  }
  tags = {}
}

resource "harvester_storageclass" "hdd_unreplicated" {
  name = "hdd-unreplicated"
  parameters = {
    "diskSelector"        = "hdd"
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
  }
  tags = {}
}

resource "harvester_storageclass" "fast" {
  name = "fast"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = var.harvester_node_count
    "staleReplicaTimeout" = "30"
    "dataLocality"        = "best-effort"
    "diskSelector"        = "ssd"
  }
}

resource "harvester_storageclass" "fast_backup" {
  name = "fast-backup"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = var.harvester_node_count
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

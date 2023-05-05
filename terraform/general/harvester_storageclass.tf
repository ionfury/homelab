resource "harvester_storageclass" "harvester_longhorn" {
  name = "harvester-longhorn"
  parameters = {
    "baseImage"           = ""
    "fromBackup"          = ""
    "migratable"          = "true"
    "numberOfReplicas"    = "3"
    "staleReplicaTimeout" = "30"
  }
  tags = {}
}
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
resource "harvester_storageclass" "longhorn-hdd" {
  description = "Hard disk storage"
  name        = "longhorn-hdd"
  parameters = {
    "migratable"          = "true"
    "staleReplicaTimeout" = "30"
    "diskSelector"        = "hdd"
    "numberOfReplicas"    = "3"
  }
  tags = {}
}
resource "harvester_storageclass" "longhorn-ssd" {
  description = "Solid state storage"
  name        = "longhorn-ssd"
  parameters = {
    "migratable"          = "true"
    "staleReplicaTimeout" = "30"
    "diskSelector"        = "ssd"
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
resource "harvester_storageclass" "hdd_weekly" {
  description = "Single replica, backed up & snapshotted weekly."
  name        = "hdd-weekly"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
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
  tags = {}
}
resource "harvester_storageclass" "hdd_nightly" {
  description = "Single replica, backed up & snapshotted nightly."
  name        = "hdd-nightly"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
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
  tags = {}
}
resource "harvester_storageclass" "ssd_unreplicated" {
  is_default = true
  name       = "ssd-unreplicated"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
    "diskSelector"        = "ssd"
  }
  tags = {}
}
resource "harvester_storageclass" "ssd_weekly" {
  description = "Single replica, backed up & snapshotted weekly"
  name        = "ssd-weekly"
  parameters = {
    "migratable"          = "true"
    "numberOfReplicas"    = "1"
    "staleReplicaTimeout" = "30"
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
  tags = {}
}
resource "harvester_storageclass" "ssd_nightly" {
  description = "Single replica, backed up & snapshotted nightly."
  name        = "ssd-nightly"
  parameters = {
    "migratable"           = "true"
    "numberOfReplicas"     = "1"
    "staleReplicaTimeout"  = "30"
    "diskSelector"         = "ssd"
    "recurringJobSelector" = "[{\"name\":\"nightly\",\"isGroup\":true\"}]"
  }
  tags = {}
}

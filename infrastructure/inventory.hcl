locals {
  hosts = {
    rpi1 = { // Pi4 2Gi
      cluster = "none"
      type    = "none"
      install = {
        selector     = "disk.dev_path == '/dev/mmcblk0'"
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      volumes = []
      bonds = [{
        link_permanentAddr = ["dc:a6:32:00:cd:cc"]
        addresses          = ["192.168.10.213"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    rpi2 = { // Pi4 2Gi
      cluster = "none"
      type    = "none"
      install = {
        selector     = "disk.dev_path == '/dev/mmcblk0'"
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      volumes = []
      bonds = [{
        link_permanentAddr = ["dc:a6:32:00:ce:5c"]
        addresses          = ["192.168.10.168"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    rpi3 = { // Pi3 B+
      cluster = "none"
      type    = "pxe"
      install = {
        selector     = "disk.dev_path == '/dev/mmcblk0'"
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      volumes = []
      bonds = [{
        link_permanentAddr = ["b8:27:eb:68:d4:92"]
        addresses          = ["192.168.10.210"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    rpi4 = { // Pi CM4 8Gi
      cluster = "none"
      type    = "controlplane"
      install = {
        selector     = "disk.size < 1u * TiB && disk.size > 100u * GiB"
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      volumes = [{
        name     = "longhorn"
        selector = "system_disk == true"
        maxSize  = "50%"
        tags     = ["fast", "nvme", "any"]
      }]
      bonds = [{
        link_permanentAddr = ["d8:3a:dd:bb:1d:7f"]
        addresses          = ["192.168.10.191"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node1 = { // Supermicro 20C@2.4GHz 64Gi
      cluster = "none"
      type    = "none"
      install = {
        selector = ""
      }
      volumes = []
      bonds = [{
        link_permanentAddr = [""]
        addresses          = [""]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node2 = { // Supermicro 20C@2.2GHz 128Gi
      cluster = "none"
      type    = "none"
      install = {
        selector = ""
      }
      volumes = []
      bonds = [{
        link_permanentAddr = ["0c:c4:7a:a4:f1:d2"]
        addresses          = ["192.168.10.182"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node3 = { // Supermicro 20C@2.2GHz 128Gi
      cluster = "none"
      type    = "none"
      install = {
        selector = ""
      }
      volumes = []
      bonds = [{
        link_permanentAddr = [""]
        addresses          = [""]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node41 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "live"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [
        { # 1920GB Kingston SSD
          name     = "kingston-ssd-1920gb-0"
          selector = "disk.dev_path == '/dev/sda'"
          maxSize  = "100%"
          tags     = ["fast", "ssd", "any"]
        },
        { # 20TB Seagate HDD
          name     = "seagate-hdd-20tb-0"
          selector = "disk.dev_path == '/dev/sdb'"
          maxSize  = "100%"
          tags     = ["slow", "hdd", "any"]
        }
      ]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:2d:bf:ee"]
        addresses          = ["192.168.10.253"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node42 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "live"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [
        { # 1920GB Kingston SSD
          name     = "kingston-ssd-1920gb-0"
          selector = "disk.dev_path == '/dev/sda'"
          maxSize  = "100%"
          tags     = ["fast", "ssd", "any"]
        },
        { # 20TB Seagate HDD
          name     = "seagate-hdd-20tb-0"
          selector = "disk.dev_path == '/dev/sdb'"
          maxSize  = "100%"
          tags     = ["slow", "hdd", "any"]
        }
      ]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:2d:bf:bc"]
        addresses          = ["192.168.10.203"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node43 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "live"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [
        { # 1TB Crucial SSD
          name     = "crucial-ssd-1tb-0"
          selector = "disk.dev_path == '/dev/sda'"
          maxSize  = "100%"
          tags     = ["fast", "ssd", "any"]
        },
        { # 1TB Crucial SSD
          name     = "crucial-ssd-1tb-1"
          selector = "disk.dev_path == '/dev/sdb'"
          maxSize  = "100%"
          tags     = ["fast", "ssd", "any"]
      }]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:2d:bb:c8"]
        addresses          = ["192.168.10.201"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node44 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "none"
      type    = "none"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [
        { # 480GB Kingston SSD
          name     = "kingston-ssd-480gb-0"
          selector = "disk.dev_path == '/dev/sda'"
          maxSize  = "100%"
          tags     = ["fast", "ssd", "any"]
        },
        { # 480GB Kingston SSD
          name     = "kingston-ssd-480gb-1"
          selector = "disk.dev_path == '/dev/sdb'"
          maxSize  = "100%"
          tags     = ["fast", "ssd", "any"]
        }
      ]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:2d:ba:1e"]
        addresses          = ["192.168.10.219"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node45 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "dev"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [{
        name     = "longhorn"
        selector = "system_disk == true"
        maxSize  = "50%"
        tags     = ["fast", "ssd", "any"]
      }]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:83:d3:2c"]
        addresses          = ["192.168.10.252"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node46 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "integration"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [{
        name     = "longhorn"
        selector = "system_disk == true"
        maxSize  = "50%"
        tags     = ["fast", "ssd", "any"]
      }]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:83:d3:1a"]
        addresses          = ["192.168.10.233"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node47 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "integration"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [{
        name     = "longhorn"
        selector = "system_disk == true"
        maxSize  = "50%"
        tags     = ["fast", "ssd", "any"]
      }]
      bonds = [{
        link_permanentAddr = ["ac:1f:6b:83:d3:24"]
        addresses          = ["192.168.10.247"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
    node48 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "integration"
      type    = "controlplane"
      install = {
        selector = "disk.model == 'Micron_5100_MTFD'"
      }
      volumes = [{
        name     = "longhorn"
        selector = "system_disk == true"
        maxSize  = "50%"
        tags     = ["fast", "ssd", "any"]
      }]
      bonds = [{
        link_permanentAddr = ["0c:c4:7a:54:9e:6a"]
        addresses          = ["192.168.10.151"]
        vlans              = [10]
        mtu                = 1500
        mode               = "active-backup"
      }]
    }
  }
}

locals {
  hosts = {
    rpi1 = { // Pi4 2Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "slow"
      }]
      install = {
        disk_filters = { id = "/dev/mmcblk0" }
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      interfaces = [{
        hardwareAddr = "dc:a6:32:00:cd:cc"
        addresses    = [{ ip = "192.168.10.213" }]
      }]
    }
    rpi2 = { // Pi4 2Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "slow"
      }]
      install = {
        disk_filters = { id = "/dev/mmcblk0" }
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      interfaces = [{
        hardwareAddr = "dc:a6:32:00:ce:5c"
        addresses    = [{ ip = "192.168.10.168" }]
      }]
    }
    rpi3 = { // Pi3 B+
      cluster = "none"
      type    = "pxe"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "slow"
      }]
      install = {
        disk_filters = { id = "/dev/mmcblk0" }
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
      }
      interfaces = [{
        hardwareAddr = "b8:27:eb:68:d4:92"
        addresses    = [{ ip = "192.168.10.210" }]
      }]
    }
    rpi4 = { // Pi CM4 8Gi
      cluster = "dev"
      type    = "controlplane"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "slow"
      }]
      install = {
        selector     = "disk.size < 1u * TiB && disk.size > 100u * GiB"
        architecture = "arm64"
        platform     = ""
        sbc          = "rpi_generic"
        data         = {
          enabled = true
          tags = ["fast", "nvme", "any"]
        }
      }
      disks = []
      interfaces = [{
        id = "end0"
        hardwareAddr = "d8:3a:dd:bb:1d:7f"
        addresses    = [{ ip = "192.168.10.191" }]
      }]
    }
    node1 = { // Supermicro 20C@2.4GHz 64Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        disk_filters = {}
      }
      interfaces = [{
        hardwareAddr = ""
        addresses    = [{ ip = "" }]
      }]
    }
    node2 = { // Supermicro 20C@2.2GHz 128Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        disk_filters = {}
      }
      interfaces = [{
        hardwareAddr = "0c:c4:7a:a4:f1:d2"
        addresses    = [{ ip = "192.168.10.182" }]
      }]
    }
    node3 = { // Supermicro 20C@2.2GHz 128Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        disk_filters = {}
      }
      interfaces = [{
        hardwareAddr = ""
        addresses    = [{ ip = "" }]
      }]
    }
    node41 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "live"
      type    = "controlplane"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = [
        { # 1920GB Kingston SSD
          device        = "/dev/sda"
          mountpoint    = "/var/mnt/disk1"
          tags = ["fast", "ssd", "any"]
        },
        { # 20TB Seagate HDD
          device        = "/dev/sdb"
          mountpoint    = "/var/mnt/disk2"
          tags = ["slow", "hdd", "any"]
        }
      ]
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:2d:bf:ee"
        addresses    = [{ ip = "192.168.10.253" }]
      }]
    }
    node42 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "live"
      type    = "controlplane"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = true
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = [
        { # 1920GB Kingston SSD
          device        = "/dev/sda"
          mountpoint    = "/var/mnt/disk1"
          tags = ["fast", "ssd", "any"]
        },
        { # 20TB Seagate HDD
          device        = "/dev/sdb"
          mountpoint    = "/var/mnt/disk2"
          tags = ["slow", "hdd", "any"]
        }
      ]
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:2d:bf:bc"
        addresses    = [{ ip = "192.168.10.203" }]
      }]
    }
    node43 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "live"
      type    = "controlplane"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = [
        { # 1TB Crucial SSD
          device        = "/dev/sda"
          mountpoint    = "/var/mnt/disk1"
          tags = ["fast", "ssd", "any"]
        },
        { # 1TB Crucial SSD
          device        = "/dev/sdb"
          mountpoint    = "/var/mnt/disk2"
          tags = ["fast", "ssd", "any"]
        }
      ]
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:2d:bb:c8"
        addresses    = [{ ip = "192.168.10.201" }]
      }]
    }
    node44 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "staging"
      type    = "controlplane"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = [
        { # 480GB Kingston SSD
          device        = "/dev/sda"
          mountpoint    = "/var/mnt/disk1"
          tags = ["fast", "ssd", "any"]
        },
        { # 480GB Kingston SSD
          device        = "/dev/sdb"
          mountpoint    = "/var/mnt/disk2"
          tags = ["fast", "ssd", "any"]
        }
      ]
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:2d:ba:1e"
        addresses    = [{ ip = "192.168.10.218" }]
      }]
    }
    node45 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "integration"
      type    = "controlplane"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = []
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:83:d3:2c"
        addresses    = [{ ip = "192.168.10.252" }]
      }]
    }
    node46 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = []
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:83:d3:1a"
        addresses    = [{ ip = "192.168.10.233" }]
      }]
    }
    node47 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = []
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "ac:1f:6b:83:d3:24"
        addresses    = [{ ip = "192.168.10.247" }]
      }]
    }
    node48 = { // Supermicro 8C@2.1GHz 32Gi
      cluster = "none"
      type    = "none"
      labels = [{
        key   = "perf.homelab.io/class"
        value = "standard"
      }]
      install = {
        selector     = "disk.model = 'Micron_5100_MTFD'"
        data         = {
          enabled = false
          tags = ["fast", "ssd", "any"]
        }
      }
      disks = []
      interfaces = [{
        id = "ens1f0"
        hardwareAddr = "0c:c4:7a:54:9e:6b"
        addresses    = [{ ip = "192.168.10.151" }]
      }]
    }
  }
}

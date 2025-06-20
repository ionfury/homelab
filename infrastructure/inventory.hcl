locals {
  hosts = {
    rpi1 = { // Dev Cluster Control Plane
      // Pi4 2Gi
      install_disk = "/dev/mmcblk0"
      endpoint = {
        mac = "dc:a6:32:00:cd:cc"
        ip  = "192.168.10.213"
      }
    }
    rpi2 = { // Dev Cluster Worker
      // Pi4 2Gi
      install_disk = "/dev/mmcblk0"
      endpoint = {
        mac = "dc:a6:32:00:ce:5c"
        ip  = "192.168.10.168"
      }
    }
    rpi3 = { // Ubuntu PXE Boot Server
      // Pi3 B+
      install_disk = "/dev/mmcblk0"
      endpoint = {
        mac = "b8:27:eb:68:d4:92"
        ip  = "192.168.10.210"
      }
    }
    rpi4 = { // Unassigned
      // Pi4 8Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = ""
        ip  = ""
      }
    }
    node1 = { // Unassigned
      // Supermicro 20C@2.4GHz 64Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = ""
        ip  = ""
      }
    }
    node2 = { // Unassigned
      // Supermicro 20C@2.2GHz 128Gi
      install_disk = "/dev/sdb"
      endpoint = {
        mac = "0c:c4:7a:a4:f1:d2"
        ip  = "192.168.10.182"
      }
    }
    node3 = { // Unassigned
      // Supermicro 20C@2.2GHz 128Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = ""
        ip  = ""
      }
    }
    node41 = { // Live Cluster Control Plane
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = "ac:1f:6b:2d:bf:ee"
        ip  = "192.168.10.253"
      }
    }
    node42 = { // Live Cluster Control Plane
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = "ac:1f:6b:2d:bf:bc"
        ip  = "192.168.10.203"
      }
    }
    node43 = { // Live Cluster Control Plane
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = "ac:1f:6b:2d:bb:c8"
        ip  = "192.168.10.201"
      }
    }
    node44 = { // Integration Cluster Control Plane
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = "ac:1f:6b:2d:ba:1e"
        ip  = "192.168.10.218"
      }
    }
    node45 = { // Staging Cluster Control Plane
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = "ac:1f:6b:2d:bf:ce"
        ip  = "192.168.10.222"
      }
    }
    node46 = { // Unassigned
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = ""
        ip  = ""
      }
    }
    node47 = { // Unassigned
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = ""
        ip  = ""
      }
    }
    node48 = { // Unassigned
      // Supermicro 8C@2.1GHz 32Gi
      install_disk = "/dev/sda"
      endpoint = {
        mac = ""
        ip  = ""
      }
    }
  }
}

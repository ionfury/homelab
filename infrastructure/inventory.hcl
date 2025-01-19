locals {
  tld = "tomnowak.work"

  raspberry_pis = {
    pxeboot = {
      lan = {
        ip  = "192.168.10.213"
        mac = "dc:a6:32:00:cd:cc"
      }
      ssh = {
        user_store = "/homelab/raspberry_pi/pxeboot/ssh/user"
        pass_store = "/homelab/raspberry_pi/pxeboot/ssh/password"
      }
    }
  }

  hosts = {
    node2 = {
      cluster = "live"
      type   = "controlplane"
      install = {
        diskSelectors   = ["wwid: 'naa.600605b00bd543602f1ddabe07b64ec8'"] # RAID controller reports SSD as 'rotational'.  Reference this via wwid: talosctl --nodes 192.168.10.182 get disks --insecure sda -o yaml | yq '.spec.wwid'
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "0c:c4:7a:a4:f1:d2"
        addresses        = ["192.168.10.182"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.182"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.249"
        mac = " 0c:c4:7a:22:41:d7"
      }
    }
    node41 = {
      cluster = "live"
      type   = "controlplane"
      install = {
        diskSelectors   = ["type: 'ssd'"]
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:bf:ee"
        addresses        = ["192.168.10.253"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.253"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.221"
        mac = "ac:1f:6b:68:2a:9b"
      }
    }
    node42 = {
      cluster = "live"
      type   = "controlplane"
      install = {
        diskSelectors   = ["type: 'ssd'"]
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:bf:bc"
        addresses        = ["192.168.10.203"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.203"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.245"
        mac = "ac:1f:6b:68:2a:b3"
      }
    }
    node43 = {
      cluster = "none"
      type   = "controlplane"
      install = {
        diskSelectors   = ["type: 'ssd'"]
        extraKernelArgs = ["apparmor=0", "init_on_alloc=0", "init_on_free=0", "mitigations=off", "security=none"]
        extensions      = ["iscsi-tools", "util-linux-tools"]
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:bb:c8"
        addresses        = ["192.168.10.201"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.201"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.223"
        mac = "ac:1f:6b:68:2a:9d"
      }
    }
    node44 = {
      cluster = "dev"
      type   = "controlplane"
      install = {
        diskSelectors   = ["type: 'ssd'"]
        extraKernelArgs = ["apparmor=0", "init_on_alloc=0", "init_on_free=0", "mitigations=off", "security=none"]
        extensions      = ["iscsi-tools", "util-linux-tools"]
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:ba:1e"
        addresses        = ["192.168.10.218"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.218"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.176"
        mac = "ac:1f:6b:68:2b:aa"
      }
    }
    node45 = {
      cluster = "dev"
      type   = "controlplane"
      install = {
        diskSelectors   = ["type: 'ssd'"]
        extraKernelArgs = ["apparmor=0", "init_on_alloc=0", "init_on_free=0", "mitigations=off", "security=none"]
        extensions      = ["iscsi-tools", "util-linux-tools"]
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:bf:ce"
        addresses        = ["192.168.10.222"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.222"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.141"
        mac = "ac:1f:6b:68:2a:4b"
      }
    }
    node46 = {
      cluster = "dev"
      type   = "controlplane"
      install = {
        diskSelectors   = ["type: 'ssd'"]
        extraKernelArgs = ["apparmor=0", "init_on_alloc=0", "init_on_free=0", "mitigations=off", "security=none"]
        extensions      = ["iscsi-tools", "util-linux-tools"]
        secureboot      = false
        wipe            = false
      }
      interfaces = [{
        hardwareAddr     = "ac:1f:6b:2d:c0:22"
        addresses        = ["192.168.10.246"]
        dhcp_routeMetric = 50
        vlans = [{
          vlanId           = 10
          addresses        = ["192.168.20.246"]
          dhcp_routeMetric = 100
        }]
      }]
      ipmi = {
        ip  = "192.168.10.231"
        mac = "ac:1f:6b:68:2b:e1"
      }
    }
  }
}

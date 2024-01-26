locals {

  harvester = {
    cluster_name = "homelab"
    kubeconfig_path = "~/.kube/harvester.yaml"
    management_address = "https://192.168.10.2"
    network_name = "citadel"

    storage = {
      fast = {
        name = "fast"
        selector = "ssd"
        is_default = true
      },
     slow = {
        name = "slow"
        selector = "hdd"
        is_default = false
      }
    }

    inventory = {
      node1 = {
        ip = "192.168.10.118"
        primary_disk = "/dev/sda"
        uplinks = [ "enp1s0f1" ]
        ipmi = {
          mac = "0c:c4:7a:22:41:d2"
          ip = "192.168.10.69"
          port = "623"
          host = "ipmi-node1"
          insecure_tls = "false"
          credentials = {
            store = "/ipmi-credentials/node1"
            username_path = "username"
            password_path = "password"
          }
        }
      },
      node2 = {
        ip = "192.168.10.43"
        primary_disk = "/dev/sda"
        uplinks = [ "enp1s0f1" ]
        ipmi = {
          mac = "0c:c4:7a:22:41:d7"
          ip = "192.168.10.74"
          port = "623"
          host = "ipmi-node2"
          insecure_tls = "false"
          credentials = {
            store = "/ipmi-credentials/node2"
            username_path = "username"
            password_path = "password"
          }
        }
      },
      node3 = {
        ip = "192.168.10.115"
        primary_disk = "/dev/sda"
        uplinks = [ "ens6f1" ]
        ipmi = {
          mac = "0c:c4:7a:8a:74:74"
          ip = "192.168.10.189"
          port = "623"
          host = "ipmi-node3"
          insecure_tls = "false"
          credentials = {
            store = "/ipmi-credentials/node3"
            username_path = "username"
            password_path = "password"
          }
        }
      }
    }
  }

  unifi = {
    address = "https://192.168.1.1"
    username = "terraform"
    password_store = "unifi-password"

    devices = {
      usw_agg_0 = {
        mac = "f4:e2:c6:59:e0:8f"
        name = "Harvester Switch"
        port_overrides = [
          # Figure out how to flatten this list later
          {
            network = "citadel"
            port = 1
          },
          {
            network = "citadel"
            port = 2
          },
          {
            network = "citadel"
            port = 3
          },
          {
            network = "citadel"
            port = 4
          },
          {
            network = "citadel"
            port = 5
          },
          {
            network = "citadel"
            port = 6
          }
        ]
      }
    }
  }

  networks = {
    citadel = {
      name = "citadel"
      vlan = 10
      cidr = "192.168.10.0/24"
      gateway = "192.168.10.1"
      netmask = "255.255.255.0"
      dhcp_cidr = "192.168.10.10/24"
      dhcp_start = 10
      dhcp_stop = 254
      site = "default"
    }
  }
}

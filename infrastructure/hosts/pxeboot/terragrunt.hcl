include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::git@github.com:ionfury/homelab-modules.git//modules/pxe-pi?ref=v0.38.0"
}

inputs = {
  raspberry_pi = "rpi3"

  raspberry_pis = {
    rpi3 = {
      lan = {
        ip  = "192.168.10.210"
        mac = "b8:27:eb:68:d4:92"
      }
      ssh = {
        user_store = "/homelab/infrastructure/hosts/rpi3/ssh/user"
        pass_store = "/homelab/infrastructure/hosts/rpi3/ssh/pass"
      }
    }
  }
}

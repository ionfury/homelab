include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "common" {
  path   = "${dirname(find_in_parent_folders("root.hcl"))}/_common/talos-cluster.hcl"
  expose = true
}

terraform {
  source = "${include.common.locals.base_source_url}?ref=v0.18.0"
}

dependencies {
  paths = ["../dns", "../users"]
}

inputs = {
  talos_version      = "v1.9.1"
  kubernetes_version = "1.30.2"

  machine_kubelet_extraMounts = [ # Support Longhorn: https://longhorn.io/docs/1.7.2/advanced-resources/os-distro-specific/talos-linux-support/#data-path-mounts
    {
      destination = "/var/lib/longhorn"
      type = "bind"
      source = "/var/lib/longhorn"
      options = [
        "bind",
        "rshared",
        "rw",
      ]
    }
  ]

  machine_files = [ # Support Spegal: https://spegel.dev/docs/getting-started/#talos
    {
      path = "/etc/cri/conf.d/20-customization.part"
      op = "create"
      permissions = "0o666"
      content = <<-EOT
        [plugins."io.containerd.cri.v1.images"]
          discard_unpacked_layers = false
      EOT
    }
  ]

  machine_extensions = [
    "iscsi-tools",
    "util-linux-tools",
  ]

  machine_extra_kernel_args = [
    "apparmor=0",
    "init_on_alloc=0",
    "init_on_free=0",
    "mitigations=off",
    "security=none"
  ]
}

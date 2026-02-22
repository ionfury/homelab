locals {
  machine_schematic_id = {
    for k in keys(local.machines) : k => try(
      data.talos_image_factory_urls.machine_image_url_sbc[k].schematic_id,
      data.talos_image_factory_urls.machine_image_url_metal[k].schematic_id
    )
  }

  machine_talos_version = {
    for k in keys(local.machines) : k => try(
      data.talos_image_factory_urls.machine_image_url_sbc[k].talos_version,
      data.talos_image_factory_urls.machine_image_url_metal[k].talos_version
    )
  }

  machine_installer = {
    for k in keys(local.machines) : k => try(
      data.talos_image_factory_urls.machine_image_url_sbc[k].urls.installer,
      data.talos_image_factory_urls.machine_image_url_metal[k].urls.installer
    )
  }

  machine_installer_secureboot = {
    for k in keys(local.machines) : k => try(
      data.talos_image_factory_urls.machine_image_url_sbc[k].urls.installer_secureboot,
      data.talos_image_factory_urls.machine_image_url_metal[k].urls.installer_secureboot
    )
  }
}

data "talos_image_factory_extensions_versions" "machine_version" {
  for_each = { for k, v in local.machines : k => v.install }

  talos_version = var.talos_version

  filters = {
    names = each.value.extensions
  }
}

resource "talos_image_factory_schematic" "machine_schematic" {
  for_each = { for k, v in local.machines : k => v.install }

  # Validate that the Image Factory resolved at least as many extensions as requested.
  # Fewer means an extension name is wrong or unavailable for this Talos version.
  # The API does substring matching (e.g. "iscsi-tools" also matches "trident-iscsi-tools"),
  # so resolved count may exceed requested count — that's expected.
  # Only checked when extensions are explicitly requested — empty filter returns all available.
  lifecycle {
    precondition {
      condition     = length(each.value.extensions) == 0 || length(data.talos_image_factory_extensions_versions.machine_version[each.key].extensions_info) >= length(each.value.extensions)
      error_message = "Extension count mismatch: requested ${length(each.value.extensions)} extensions [${join(", ", each.value.extensions)}] but Image Factory resolved only ${length(data.talos_image_factory_extensions_versions.machine_version[each.key].extensions_info)} for Talos ${var.talos_version}. Check extension names are valid."
    }
  }

  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          # Use resolved extensions only when explicitly requested.
          # Empty filter returns all available extensions — never include those.
          officialExtensions = length(each.value.extensions) > 0 ? data.talos_image_factory_extensions_versions.machine_version[each.key].extensions_info[*].name : []
        }
        extraKernelArgs = concat(each.value.extra_kernel_args)
        secureboot = {
          enabled = each.value.secureboot
        }
      }
    }
  )
}

data "talos_image_factory_urls" "machine_image_url_metal" {
  for_each = { for k, v in local.machines : k => v.install if v.install.platform != "" }

  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.machine_schematic[each.key].id
  platform      = each.value.platform
  architecture  = each.value.architecture
}

data "talos_image_factory_urls" "machine_image_url_sbc" {
  for_each = { for k, v in local.machines : k => v.install if v.install.sbc != "" }

  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.machine_schematic[each.key].id
  architecture  = each.value.architecture
  sbc           = each.value.sbc
}

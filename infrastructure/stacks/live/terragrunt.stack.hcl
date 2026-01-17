locals {
  name                 = "${basename(get_terragrunt_dir())}"
  features             = ["gateway-api", "longhorn", "prometheus", "spegel"]
  storage_provisioning = "normal"
}

unit "config" {
  source = "../../units/config"
  path   = "config"

  values = {
    name                 = local.name
    features             = local.features
    storage_provisioning = local.storage_provisioning
  }
}

unit "unifi" {
  source = "../../units/unifi"
  path   = "unifi"
}

unit "talos" {
  source = "../../units/talos"
  path   = "talos"
}

unit "bootstrap" {
  source = "../../units/bootstrap"
  path   = "bootstrap"
}

unit "aws_set_params" {
  source = "../../units/aws-set-params"
  path   = "aws-set-params"
}

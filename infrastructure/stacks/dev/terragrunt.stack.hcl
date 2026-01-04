locals {
  name     = "${basename(get_terragrunt_dir())}"
  features = ["gateway-api", "longhorn", "prometheus", "spegel"]
}

unit "aws_get_params" {
  source = "../../units/aws-get-params"
  path   = "aws-get-params"
}

unit "config" {
  source = "../../units/config"
  path   = "config"

  values = {
    name     = local.name
    features = local.features
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

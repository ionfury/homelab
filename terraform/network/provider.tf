data "aws_ssm_parameter" "unifi_password" {
  name = var.unifi_management_password_store
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "unifi" {
  api_url        = var.unifi_management_address
  password       = data.aws_ssm_parameter.unifi_password.value
  username       = var.unifi_management_username
  allow_insecure = true
}

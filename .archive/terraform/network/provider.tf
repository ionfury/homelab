data "aws_ssm_parameter" "unifi_password" {
  name = var.unifi.password_store
}

provider "aws" {
  region  = var.aws.region
  profile = var.aws.profile
}

provider "unifi" {
  api_url        = var.unifi.address
  password       = data.aws_ssm_parameter.unifi_password.value
  username       = var.unifi.username
  allow_insecure = true
}

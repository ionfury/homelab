data "aws_ssm_parameter" "unifi_api_key" {
  name = var.unifi.api_key_store
}

provider "unifi" {
  api_url        = var.unifi.address
  api_key        = data.aws_ssm_parameter.unifi_api_key.value
  username       = ""
  password       = ""
  allow_insecure = true
  site           = var.unifi.site
}

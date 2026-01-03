provider "unifi" {
  api_url        = var.unifi.address
  api_key        = var.unifi.api_key
  username       = ""
  password       = ""
  allow_insecure = true
  site           = var.unifi.site
}

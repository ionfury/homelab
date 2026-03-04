mock_provider "unifi" { alias = "mock" }
mock_provider "aws" { alias = "mock" }

variables {
  unifi = {
    address       = "https://10.10.10.10"
    site          = "default"
    api_key_store = "/test/api-key"
  }
  external_ingress_ip = "192.168.10.23"
  external_tld        = "external.tomnowak.work"
}

run "port_forward_http" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  assert {
    condition     = unifi_port_forward.http.dst_port == "80"
    error_message = "HTTP port forward dst_port should be 80"
  }
  assert {
    condition     = unifi_port_forward.http.fwd_ip == "192.168.10.23"
    error_message = "HTTP port forward should target external ingress IP"
  }
  assert {
    condition     = unifi_port_forward.http.fwd_port == "80"
    error_message = "HTTP port forward fwd_port should be 80"
  }
}

run "port_forward_https" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  assert {
    condition     = unifi_port_forward.https.dst_port == "443"
    error_message = "HTTPS port forward dst_port should be 443"
  }
  assert {
    condition     = unifi_port_forward.https.fwd_ip == "192.168.10.23"
    error_message = "HTTPS port forward should target external ingress IP"
  }
  assert {
    condition     = unifi_port_forward.https.fwd_port == "443"
    error_message = "HTTPS port forward fwd_port should be 443"
  }
}

run "resource_naming" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  assert {
    condition     = unifi_port_forward.http.name == "External Gateway HTTP"
    error_message = "HTTP port forward name incorrect"
  }
  assert {
    condition     = unifi_port_forward.https.name == "External Gateway HTTPS"
    error_message = "HTTPS port forward name incorrect"
  }
}

mock_provider "unifi" { alias = "mock" }
mock_provider "aws" { alias = "mock" }

variables {
  unifi = {
    address       = "https://10.10.10.10"
    site          = "default"
    api_key_store = "/test/api-key"
  }
  port_forwards = {}
  dynamic_dns   = {}
}

run "external_gateway_forwards" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  variables {
    port_forwards = {
      external_gateway_http = {
        name     = "External Gateway HTTP"
        dst_port = "80"
        fwd_ip   = "192.168.10.23"
        fwd_port = "80"
        protocol = "tcp"
      }
      external_gateway_https = {
        name     = "External Gateway HTTPS"
        dst_port = "443"
        fwd_ip   = "192.168.10.23"
        fwd_port = "443"
        protocol = "tcp"
      }
    }
  }

  assert {
    condition     = length(unifi_port_forward.rule) == 2
    error_message = "Two port forward rules should be created"
  }
  assert {
    condition     = unifi_port_forward.rule["external_gateway_http"].dst_port == "80"
    error_message = "HTTP port forward dst_port should be 80"
  }
  assert {
    condition     = unifi_port_forward.rule["external_gateway_http"].fwd_ip == "192.168.10.23"
    error_message = "HTTP port forward should target external ingress IP"
  }
  assert {
    condition     = unifi_port_forward.rule["external_gateway_https"].dst_port == "443"
    error_message = "HTTPS port forward dst_port should be 443"
  }
  assert {
    condition     = unifi_port_forward.rule["external_gateway_https"].name == "External Gateway HTTPS"
    error_message = "HTTPS port forward name incorrect"
  }
}

run "game_server_forward" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  variables {
    port_forwards = {
      minecraft = {
        name     = "Minecraft Server"
        dst_port = "25565"
        fwd_ip   = "192.168.10.23"
        fwd_port = "25565"
        protocol = "tcp"
      }
    }
  }

  assert {
    condition     = length(unifi_port_forward.rule) == 1
    error_message = "Single port forward rule should be created"
  }
  assert {
    condition     = unifi_port_forward.rule["minecraft"].name == "Minecraft Server"
    error_message = "Game server port forward name incorrect"
  }
  assert {
    condition     = unifi_port_forward.rule["minecraft"].dst_port == "25565"
    error_message = "Game server port forward dst_port incorrect"
  }
}

run "empty_forwards" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  assert {
    condition     = length(unifi_port_forward.rule) == 0
    error_message = "No port forwards should be created with empty input"
  }
  assert {
    condition     = length(unifi_dynamic_dns.record) == 0
    error_message = "No dynamic DNS entries should be created with empty input"
  }
}

run "dynamic_dns_cloudflare" {
  command   = plan
  providers = { unifi = unifi.mock, aws = aws.mock }

  variables {
    dynamic_dns = {
      external_gateway = {
        service        = "cloudflare"
        host_name      = "gw.example.com"
        server         = ""
        login          = "example.com"
        password_store = "/test/cloudflare-token"
      }
    }
  }

  assert {
    condition     = length(unifi_dynamic_dns.record) == 1
    error_message = "Single dynamic DNS entry should be created"
  }
  assert {
    condition     = unifi_dynamic_dns.record["external_gateway"].service == "cloudflare"
    error_message = "Dynamic DNS service should be cloudflare"
  }
  assert {
    condition     = unifi_dynamic_dns.record["external_gateway"].host_name == "gw.example.com"
    error_message = "Dynamic DNS host_name should be the gateway anchor record"
  }
  assert {
    condition     = unifi_dynamic_dns.record["external_gateway"].login == "example.com"
    error_message = "Dynamic DNS login should be the Cloudflare zone name"
  }
}

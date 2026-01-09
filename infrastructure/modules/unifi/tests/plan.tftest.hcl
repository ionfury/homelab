# Plan tests for unifi module - validates DNS and DHCP resource creation

mock_provider "unifi" {
  alias = "mock"
}

variables {
  unifi = {
    address       = "https://10.10.10.10"
    site          = "site"
    api_key_store = "/homelab/infrastructure/accounts/unifi/api-key"
  }
  cluster_endpoint = "endpoint.example.com"
}

run "multiple_dns_and_dhcp" {
  command = plan
  providers = {
    unifi = unifi.mock
  }

  variables {
    dns_records = {
      a = {
        name   = "endpoint.example.com"
        record = "1.1.1.1"
      }
      b = {
        name   = "endpoint.example.com"
        record = "2.2.2.2"
      }
    }

    dhcp_reservations = {
      a = {
        mac = "aa:aa:aa:aa:aa:aa"
        ip  = "1.1.1.1"
      }
      b = {
        mac = "bb:bb:bb:bb:bb:bb"
        ip  = "2.2.2.2"
      }
      c = {
        mac = "cc:cc:cc:cc:cc:cc"
        ip  = "3.3.3.3"
      }
    }
  }

  assert {
    condition     = unifi_dns_record.record["a"].record == "1.1.1.1"
    error_message = "DNS Record at 'a' not as expected'."
  }

  assert {
    condition     = unifi_dns_record.record["a"].name == "endpoint.example.com"
    error_message = "DNS Record at 'a' not as expected'."
  }

  assert {
    condition     = length(unifi_dns_record.record) == 2
    error_message = "DNS Record length not as expected!"
  }

  assert {
    condition     = length(unifi_user.user) == 3
    error_message = "User length is not as expected!"
  }

  assert {
    condition     = unifi_user.user["a"].name == "a" && unifi_user.user["a"].mac == "aa:aa:aa:aa:aa:aa" && unifi_user.user["a"].fixed_ip == "1.1.1.1"
    error_message = "Unifi user[a] is not as expected!"
  }
}

run "empty_dns_records" {
  command = plan
  providers = {
    unifi = unifi.mock
  }

  variables {
    dns_records = {}
    dhcp_reservations = {
      a = {
        mac = "aa:aa:aa:aa:aa:aa"
        ip  = "1.1.1.1"
      }
    }
  }

  assert {
    condition     = length(unifi_dns_record.record) == 0
    error_message = "No DNS records should be created with empty input"
  }

  assert {
    condition     = length(unifi_user.user) == 1
    error_message = "DHCP reservation should still be created"
  }
}

run "empty_dhcp_reservations" {
  command = plan
  providers = {
    unifi = unifi.mock
  }

  variables {
    dns_records = {
      a = {
        name   = "endpoint.example.com"
        record = "1.1.1.1"
      }
    }
    dhcp_reservations = {}
  }

  assert {
    condition     = length(unifi_dns_record.record) == 1
    error_message = "DNS record should still be created"
  }

  assert {
    condition     = length(unifi_user.user) == 0
    error_message = "No DHCP reservations should be created with empty input"
  }
}

run "both_empty" {
  command = plan
  providers = {
    unifi = unifi.mock
  }

  variables {
    dns_records       = {}
    dhcp_reservations = {}
  }

  assert {
    condition     = length(unifi_dns_record.record) == 0
    error_message = "No DNS records should be created"
  }

  assert {
    condition     = length(unifi_user.user) == 0
    error_message = "No DHCP reservations should be created"
  }
}

run "single_dns_record" {
  command = plan
  providers = {
    unifi = unifi.mock
  }

  variables {
    dns_records = {
      single = {
        name   = "single.example.com"
        record = "10.10.10.10"
      }
    }
    dhcp_reservations = {}
  }

  assert {
    condition     = length(unifi_dns_record.record) == 1
    error_message = "Single DNS record should be created"
  }

  assert {
    condition     = unifi_dns_record.record["single"].name == "single.example.com"
    error_message = "DNS record name incorrect"
  }

  assert {
    condition     = unifi_dns_record.record["single"].record == "10.10.10.10"
    error_message = "DNS record IP incorrect"
  }
}

run "single_dhcp_reservation" {
  command = plan
  providers = {
    unifi = unifi.mock
  }

  variables {
    dns_records = {}
    dhcp_reservations = {
      single = {
        mac = "dd:dd:dd:dd:dd:dd"
        ip  = "192.168.1.100"
      }
    }
  }

  assert {
    condition     = length(unifi_user.user) == 1
    error_message = "Single DHCP reservation should be created"
  }

  assert {
    condition     = unifi_user.user["single"].mac == "dd:dd:dd:dd:dd:dd"
    error_message = "DHCP reservation MAC incorrect"
  }

  assert {
    condition     = unifi_user.user["single"].fixed_ip == "192.168.1.100"
    error_message = "DHCP reservation IP incorrect"
  }

  assert {
    condition     = unifi_user.user["single"].name == "single"
    error_message = "DHCP reservation name should be the key"
  }
}

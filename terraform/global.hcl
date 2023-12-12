locals {
  tld = "tomnowak.work"

  external_secrets_access_key_store = "k8s-external-secrets"

  healthchecksio = {
    api_key_store = "healthchecksio-api-key"
  }

  aws = {
    region = "us-east-2"
    profile = "terragrunt"
  }

  github = {
    email = "ionfury@gmail.com"
    user = "ionfury"
    name = "Tom"

    ssh_addr = "ssh://git@github.com/ionfury/homelab.git"
    ssh_pub = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAWC1V3EXflFNRrdYCBeS+8v5wSNdGSj62HMdELk70cuCPOURYenvW8lFPJU+gzLeYvXyONbw7yzi66Or/aryzKsF6Nh+m49RHo9tSLH14x23dkH3JzhUMHhUZVTiD+yQS1NQeCB3cgysE0WQbpgeKLfKhDQUFdx+3o6uhJviufrK6IeheVQg16l00d8Ttn6faTUWfWwbUlDhD5NutMApcyJg78xgwFPKy6/1z2Y8zJyBpME7e8D3AOnq3UE1eGQHUlSMjeEMwJk04D9nF8teIgzk806ZKfWx9670bFD6Dcq/EeUUBRugS9t/q82A0Kme/GxZGRkGYIrpXo2wK2EPgttru0URFPahi31OPuv+DTf/RgnfA8eo91ERycDUTEWe833GD7L99lQdJjPsQ0gaEXRLXG8v/z5NJ4aOj121aK8IyoNR7Vtq4MnstsehXYbjHYl17SQCmORqgSFVTlgTobUo3jPfOvY3PN8ew5/rxfpBsh9cYtFahb3fhsEu6lLluFGX8TuZFvj2lM535oEbbDDDXoKqpW5hJfjZE/l5H+0x11w8kVLbQe+NQkrOpME9gnOqi7JSnqzdWdnn0NP6wq1cG5iWCFr+iQ+m9UwF0stSer/u4qvkEDNvcSN/s47Xit/5pFisBPNYpTz4jOj9eg/pqGxBPFFW8k44mdy/yCQ== flux@tomnowak.work"
    ssh_known_hosts = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg= github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="

    token_store = "github-token"
    oauth_secret_store = "github-oauth-rancher-tomnowak-work-secret"
    oauth_clientid_store = "github-oauth-rancher-tomnowak-work-clientid"
    ssh_key_store = "terraform-flux-key"
  }

  harvester = {
    cluster_name = "homelab"
    kubeconfig_path = "~/.kube/harvester"
    management_address = "https://192.168.10.2"
    network_name = "citadel"

    storage = {
      fast = {
        name = "fast"
        selector = "ssd"
        is_default = true
      },
     slow = {
        name = "slow"
        selector = "hdd"
        is_default = false
      }
    }

    inventory = {
      node1 = {
        primary_disk = "/dev/sda"
        mac = "0c:c4:7a:22:41:d2"
        host = "node1"
        uplink = [ "enp1s0f1" ]
        ip = "192.168.10.69"
        port = "623"
        insecure_tls = "false"
        credentials = {
          store = "/ipmi-credentials/node1"
          username_path = "username"
          password_path = "password"
        }
      }
    }

    uplink = [
      "eno2",
      "eno3"
    ]

    node_count = 1
  }

  rancher = {
    cluster_name = "rancher"
    ssh_key_name = "id-rsa-homelab-ssh-mac"
    rancher_version = "2.7.6"
    kubernetes_version = "v1.26.4-rancher2-1"
    cert_manager_version = "1.12.0"

    node_memory = "16Gi"
    node_cpu = 2
    node_count = 1
  }

  cloudflare = {
    account_name = "homelab"
    email = "ionfury@gmail.com"
    api_key_store = "cloudflare-api-key"
  }

  unifi = {
    address = "https://192.168.1.1"
    username = "terraform"
    password_store = "unifi-password"

    devices = {
      usw_agg_0 = {
        mac = "f4:e2:c6:59:e0:8f"
        name = "Harvester Switch"
        port_overrides = [
          # Figure out how to flatten this list later
          {
            network = "citadel"
            port = 1
          },
          {
            network = "citadel"
            port = 2
          },
          {
            network = "citadel"
            port = 3
          },
          {
            network = "citadel"
            port = 4
          },
          {
            network = "citadel"
            port = 5
          },
          {
            network = "citadel"
            port = 6
          }
        ]
      }
    }
  }

  networks = {
    citadel = {
      name = "citadel"
      vlan = 10
      cidr = "192.168.10.0/24"
      gateway = "192.168.10.1"
      netmask = "255.255.255.0"
      dhcp_cidr = "192.168.10.10/24"
      dhcp_start = 10
      dhcp_stop = 254
      site = "default"
    }
  }

  public_ssh_keys = [
    {
      description = "SSH key from mac laptop"
      name = "id-rsa-homelab-ssh-mac"
      public_key =  "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCjzNYlwnjIcr4I8cbQWW5ZZAvPhMklmdAD2sL9Wm5WyAkJ9ui86uZ4KpVG7ymr9/eHkR6VrBuBbAIhKpbnRerhQkbmWuXRj3O6aExFMwZXMi1p+TMtQ/RvO0BqV3EVzFUlE/Ry45oML45gC/E7rvUgbQg5skXzbQYh/TVjIlcPWmLunVgC5+5fO7ByhKrfiqPnEZ4iG1Pnt0BuPIJeEJhbVqmEzikbTtQ5ZhBPAk37s+aHxYg7okOhxW0709ninICHlYc+FicV9sd6jfqaBa31ydolkSpsy8KV8+n1KEkntQD+pFRdjk7Rroab2zDyKhuqO1l/k7BEPzKvuIMIoU07vZ5EKZHIC7Rp/kArOIZ1gmO/nRQvA5R34ovOqJeGR7DFa++PzucuW3Y83hHjg4E82tTtqSgcyjlX9EGjYs0dxQoX5l43IcTxFp0QGS6g7qG8u/PKV/uqS2cEbMCS9YBupvu83H2WBsWL5XEk2iC/q93WZXa2/QGdLwZMv1r6q58= tnowak@TWML-TNOWAK"
    }
  ]
}

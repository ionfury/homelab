locals {
  domains = {
    internal = "tomnowak.work"
    external = "tomnowak.work"
  }

  subnets = {
    citadel = "192.168.10.0/24"
  }

  nameservers = ["192.168.10.1"]
  timeservers = ["0.pool.ntp.org", "1.pool.ntp.org"]

  clusters = {
    live = {
      id           = 1
      internal_tld = "internal.${local.domains.internal}"
      external_tld = "external.${local.domains.external}"

      node_subnet         = local.subnets.citadel
      pod_subnet          = "172.18.0.0/16"
      service_subnet      = "172.19.0.0/16"
      vip                 = "192.168.10.20"
      ip_pool_start       = "192.168.10.21"
      internal_ingress_ip = "192.168.10.22"
      external_ingress_ip = "192.168.10.23"
      ip_pool_stop        = "192.168.10.29"

      nameservers = local.nameservers
      timeservers = local.timeservers
    }
    integration = {
      id           = 2
      internal_tld = "internal.integration.${local.domains.internal}"
      external_tld = "external.integration.${local.domains.external}"

      node_subnet         = local.subnets.citadel
      pod_subnet          = "172.20.0.0/16"
      service_subnet      = "172.21.0.0/16"
      vip                 = "192.168.10.30"
      ip_pool_start       = "192.168.10.31"
      internal_ingress_ip = "192.168.10.32"
      external_ingress_ip = "192.168.10.33"
      ip_pool_stop        = "192.168.10.39"

      nameservers = local.nameservers
      timeservers = local.timeservers
    }
    staging = {
      id           = 3
      internal_tld = "internal.staging.${local.domains.internal}"
      external_tld = "external.staging.${local.domains.external}"

      node_subnet         = local.subnets.citadel
      pod_subnet          = "172.22.0.0/16"
      service_subnet      = "172.23.0.0/16"
      vip                 = "192.168.10.40"
      ip_pool_start       = "192.168.10.41"
      internal_ingress_ip = "192.168.10.42"
      external_ingress_ip = "192.168.10.43"
      ip_pool_stop        = "192.168.10.49"

      nameservers = local.nameservers
      timeservers = local.timeservers
    }
    dev = {
      id           = 4
      internal_tld = "internal.dev.${local.domains.internal}"
      external_tld = "internal.dev.${local.domains.external}"

      node_subnet         = local.subnets.citadel
      pod_subnet          = "172.24.0.0/16"
      service_subnet      = "172.25.0.0/16"
      vip                 = "192.168.10.50"
      ip_pool_start       = "192.168.10.51"
      internal_ingress_ip = "192.168.10.52"
      external_ingress_ip = "192.168.10.53"
      ip_pool_stop        = "192.168.10.59"

      nameservers = local.nameservers
      timeservers = local.timeservers
    }
  }
}

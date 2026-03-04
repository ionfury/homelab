variable "external_ingress_ip" {
  description = "Internal IP of the external ingress gateway (Cilium LB)."
  type        = string
}

variable "external_tld" {
  description = "External TLD for the cluster (e.g. external.tomnowak.work)."
  type        = string
}

variable "unifi" {
  description = "Unifi controller configuration."
  type = object({
    address       = string
    site          = string
    api_key_store = string
  })
}

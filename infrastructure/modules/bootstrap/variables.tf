variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "flux_version" {
  description = "Version of Flux to install"
  type        = string
  default     = "v2.4.0"
}

variable "cluster_env_vars" {
  description = "Environment variables to add to the cluster git repository root directory, to be consumed by flux. See: https://fluxcd.io/flux/components/kustomize/kustomizations/#post-build-variable-substitution"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "healthchecksio_replication_allowed_namespaces" {
  description = "Namespaces to allow replication for healthchecks.io.  See: https://github.com/mittwald/kubernetes-replicator?tab=readme-ov-file#pull-based-replication"
  type        = string
  default     = "monitoring"
}

variable "kubeconfig" {
  description = "Credentials to access kubernetes cluster"
  type = object({
    host                   = string
    client_certificate     = string
    client_key             = string
    cluster_ca_certificate = string
  })
}

variable "github" {
  description = "The GitHub repository to use."
  type = object({
    org             = string
    repository      = string
    repository_path = string
    token_store     = string
  })
}

variable "external_secrets" {
  description = "The external secret store."
  type = object({
    id_store     = string
    secret_store = string
  })
}

variable "healthchecksio" {
  description = "The healthchecks.io account to use."
  type = object({
    api_key_store = string
  })
}

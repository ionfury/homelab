variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "flux_version" {
  description = "Version of Flux to install"
  type        = string
  default     = "v2.4.0"
}

variable "cluster_vars" {
  description = "Non-version environment variables for flux post-build substitution."
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

variable "source_type" {
  description = "Flux sync source: 'git' or 'oci'"
  type        = string
  default     = "git"
  validation {
    condition     = contains(["git", "oci"], var.source_type)
    error_message = "source_type must be 'git' or 'oci'"
  }
}

variable "oci_url" {
  description = "OCI artifact URL (required when source_type = 'oci')"
  type        = string
  default     = ""
}

variable "oci_tag_pattern" {
  description = "Tag pattern for ImagePolicy (e.g., 'integration-*')"
  type        = string
  default     = ""
}

variable "oci_semver" {
  description = "Semver constraint for OCIRepository (e.g., '>= 0.0.0-0' includes pre-releases)"
  type        = string
  default     = ""
}

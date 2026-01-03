variable "talos_version" {
  description = "The version of Talos to use."
  type        = string
}

variable "kubernetes_version" {
  description = "The version of kubernetes to deploy."
  type        = string
}

variable "talos_machines" {
  description = "A list of machines to create the talos cluster from. See: https://docs.siderolabs.com/talos/v1.10/reference/configuration/v1alpha1/config"
  type = list(object({
    config = string
    image = optional(object({
      extensions        = optional(list(string), [])
      extra_kernel_args = optional(list(string), [])
      secureboot        = optional(bool, false)
      architecture      = optional(string, "amd64")
      platform          = optional(string, "metal")
      sbc               = optional(string, "")
    }), {})
  }))
  validation {
    condition     = length(var.talos_machines) > 0
    error_message = "At least one machine must be provided."
  }

  validation {
    error_message = "Each machine's config must be valid yaml."
    condition     = alltrue([for m in var.talos_machines : can(yamlencode(m.config))])
  }

  validation {
    error_message = "You must not provide a config.machine.install.image value. The module will populate this automatically."
    condition = alltrue([
      for m in var.talos_machines :
      !can(yamldecode(m.config).machine.install.image)
    ])
  }

  validation {
    error_message = "If architecture is amd64, sbc must be empty."
    condition     = alltrue([for m in var.talos_machines : !(m.image.architecture == "amd64" && m.image.sbc != "")])
  }
}

variable "on_destroy" {
  description = "How to preform node destruction"
  type = object({
    graceful = bool
    reboot   = bool
    reset    = bool
  })
  default = {
    graceful = false
    reboot   = true
    reset    = true
  }
}

variable "talos_config_path" {
  description = "The path to output the Talos configuration file."
  type        = string
  default     = "~/.talos"
}

variable "kubernetes_config_path" {
  description = "The path to output the Kubernetes configuration file."
  type        = string
  default     = "~/.kube"
}

variable "talos_timeout" {
  description = "The timeout to use for the Talos cluster."
  type        = string
  default     = "10m"
}

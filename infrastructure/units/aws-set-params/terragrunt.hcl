include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../.././/modules/aws-set-params"
}

dependency "config" {
  config_path = "../config"

  mock_outputs = {
    aws_set_params = {
      kubeconfig_path  = "/mock/kubeconfig"
      talosconfig_path = "/mock/talosconfig"
    }
    cluster_name = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "talos" {
  config_path = "../talos"

  mock_outputs = {
    kubeconfig_raw  = "mock"
    talosconfig_raw = "mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "longhorn_s3_backup" {
  config_path = "../longhorn-s3-backup"

  mock_outputs = {
    access_key_id     = "mock-access-key"
    secret_access_key = "mock-secret-key"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  params = {
    kubeconfig = {
      name        = dependency.config.outputs.aws_set_params.kubeconfig_path
      description = "Kubeconfig for cluster '${dependency.config.outputs.cluster_name}'."
      type        = "SecureString"
      value       = dependency.talos.outputs.kubeconfig_raw
    }
    talosconfig = {
      name        = dependency.config.outputs.aws_set_params.talosconfig_path
      description = "Talosconfig for cluster '${dependency.config.outputs.cluster_name}'."
      type        = "SecureString"
      value       = dependency.talos.outputs.talosconfig_raw
    }
    longhorn_s3_access_key_id = {
      name        = "/homelab/kubernetes/${dependency.config.outputs.cluster_name}/longhorn-s3-backup/access-key-id"
      description = "AWS access key ID for Longhorn S3 backup in cluster '${dependency.config.outputs.cluster_name}'."
      type        = "SecureString"
      value       = dependency.longhorn_s3_backup.outputs.access_key_id
    }
    longhorn_s3_secret_access_key = {
      name        = "/homelab/kubernetes/${dependency.config.outputs.cluster_name}/longhorn-s3-backup/secret-access-key"
      description = "AWS secret access key for Longhorn S3 backup in cluster '${dependency.config.outputs.cluster_name}'."
      type        = "SecureString"
      value       = dependency.longhorn_s3_backup.outputs.secret_access_key
    }
  }
}

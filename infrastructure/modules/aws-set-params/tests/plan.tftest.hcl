# Plan tests for aws-set-params module - validates SSM parameter creation

mock_provider "aws" {
  alias = "mock"
}

run "single_parameter" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    params = {
      test-param = {
        name  = "/test/parameter"
        type  = "String"
        value = "test-value"
      }
    }
  }

  assert {
    condition     = length(aws_ssm_parameter.this) == 1
    error_message = "Expected 1 SSM parameter to be created"
  }

  assert {
    condition     = aws_ssm_parameter.this["test-param"].name == "/test/parameter"
    error_message = "Parameter name incorrect"
  }

  assert {
    condition     = aws_ssm_parameter.this["test-param"].type == "String"
    error_message = "Parameter type should be String"
  }

  assert {
    condition     = aws_ssm_parameter.this["test-param"].value == "test-value"
    error_message = "Parameter value incorrect"
  }

  assert {
    condition     = aws_ssm_parameter.this["test-param"].tags["managed-by"] == "terraform"
    error_message = "managed-by tag should be set to terraform"
  }
}

run "multiple_parameters" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    params = {
      kubeconfig = {
        name        = "/homelab/clusters/test/kubeconfig"
        description = "Kubernetes configuration"
        type        = "SecureString"
        value       = "kubeconfig-content"
      }
      talosconfig = {
        name        = "/homelab/clusters/test/talosconfig"
        description = "Talos configuration"
        type        = "SecureString"
        value       = "talosconfig-content"
      }
      api-key = {
        name  = "/homelab/accounts/service/api-key"
        type  = "SecureString"
        value = "secret-key"
      }
    }
  }

  assert {
    condition     = length(aws_ssm_parameter.this) == 3
    error_message = "Expected 3 SSM parameters to be created"
  }

  assert {
    condition     = aws_ssm_parameter.this["kubeconfig"].type == "SecureString"
    error_message = "kubeconfig should be SecureString type"
  }

  assert {
    condition     = aws_ssm_parameter.this["talosconfig"].type == "SecureString"
    error_message = "talosconfig should be SecureString type"
  }
}

run "parameter_with_description" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    params = {
      described = {
        name        = "/test/described"
        description = "A parameter with a description"
        type        = "String"
        value       = "value"
      }
    }
  }

  assert {
    condition     = aws_ssm_parameter.this["described"].description == "A parameter with a description"
    error_message = "Description should be set"
  }
}

run "parameter_without_description" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    params = {
      nodesc = {
        name  = "/test/nodesc"
        type  = "String"
        value = "value"
      }
    }
  }

  assert {
    condition     = aws_ssm_parameter.this["nodesc"].description == null
    error_message = "Description should be null when not provided"
  }
}

run "securestring_type" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    params = {
      secret = {
        name  = "/test/secret"
        type  = "SecureString"
        value = "sensitive-data"
      }
    }
  }

  assert {
    condition     = aws_ssm_parameter.this["secret"].type == "SecureString"
    error_message = "Parameter type should be SecureString"
  }
}

run "empty_params" {
  command = plan
  providers = {
    aws = aws.mock
  }

  variables {
    params = {}
  }

  assert {
    condition     = length(aws_ssm_parameter.this) == 0
    error_message = "No parameters should be created with empty input"
  }
}

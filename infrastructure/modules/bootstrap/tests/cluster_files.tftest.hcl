# Plan tests for bootstrap module - validates cluster file generation

mock_provider "github" {
  alias = "mock"
}

mock_provider "kubernetes" {
  alias = "mock"
}

mock_provider "helm" {
  alias = "mock"
}

mock_provider "healthchecksio" {
  alias = "mock"

  # Provider v2.3.0+ validates channel IDs as UUIDs
  override_data {
    target = data.healthchecksio_channel.this
    values = {
      id = "00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "aws" {
  alias = "mock"
}

variables {
  cluster_name = "test-cluster"
  flux_version = "v2.4.0"
  cluster_vars = [
    { name = "cluster_name", value = "test-cluster" },
    { name = "cluster_tld", value = "internal.test.example.com" },
    { name = "cluster_endpoint", value = "k8s.internal.test.example.com" },
    { name = "cluster_vip", value = "10.0.0.100" },
  ]
  kubeconfig = {
    host                   = "https://localhost:6443"
    client_certificate     = "mock-cert"
    client_key             = "mock-key"
    cluster_ca_certificate = "mock-ca"
  }
  github = {
    org             = "test-org"
    repository      = "test-repo"
    repository_path = "kubernetes/clusters"
    token_store     = "/test/github/token"
  }
  external_secrets = {
    id_store     = "/test/external-secrets/id"
    secret_store = "/test/external-secrets/secret"
  }
  healthchecksio = {
    api_key_store = "/test/healthchecksio/api-key"
  }
}

run "creates_cluster_vars_file" {
  command = plan
  providers = {
    github         = github.mock
    kubernetes     = kubernetes.mock
    helm           = helm.mock
    healthchecksio = healthchecksio.mock
    aws            = aws.mock
  }

  assert {
    condition     = github_repository_file.cluster_vars.file == "kubernetes/clusters/test-cluster/.cluster-vars.env"
    error_message = "cluster_vars file path incorrect"
  }

  assert {
    condition     = can(regex("cluster_name=test-cluster", github_repository_file.cluster_vars.content))
    error_message = "cluster_vars content should contain cluster_name"
  }

  assert {
    condition     = can(regex("cluster_vip=10.0.0.100", github_repository_file.cluster_vars.content))
    error_message = "cluster_vars content should contain cluster_vip"
  }
}

# NOTE: kustomization.yaml and platform.yaml are now static files committed to git
# rather than Terraform-managed resources. See kubernetes/clusters/{integration,live}/
# These tests were removed as part of the OCI artifact promotion implementation.

run "empty_vars_still_creates_files" {
  command = plan
  providers = {
    github         = github.mock
    kubernetes     = kubernetes.mock
    helm           = helm.mock
    healthchecksio = healthchecksio.mock
    aws            = aws.mock
  }

  variables {
    cluster_vars = []
  }

  assert {
    condition     = github_repository_file.cluster_vars.file == "kubernetes/clusters/test-cluster/.cluster-vars.env"
    error_message = "cluster_vars file should be created even with empty vars"
  }
}

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
  version_vars = [
    { name = "talos_version", value = "v1.12.1" },
    { name = "kubernetes_version", value = "1.34.0" },
    { name = "flux_version", value = "v2.4.0" },
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

run "creates_versions_file" {
  command = plan
  providers = {
    github         = github.mock
    kubernetes     = kubernetes.mock
    helm           = helm.mock
    healthchecksio = healthchecksio.mock
    aws            = aws.mock
  }

  assert {
    condition     = github_repository_file.versions.file == "kubernetes/clusters/test-cluster/.versions.env"
    error_message = "versions file path incorrect"
  }

  assert {
    condition     = can(regex("talos_version=v1.12.1", github_repository_file.versions.content))
    error_message = "versions content should contain talos_version"
  }

  assert {
    condition     = can(regex("kubernetes_version=1.34.0", github_repository_file.versions.content))
    error_message = "versions content should contain kubernetes_version"
  }
}

run "creates_kustomization_file" {
  command = plan
  providers = {
    github         = github.mock
    kubernetes     = kubernetes.mock
    helm           = helm.mock
    healthchecksio = healthchecksio.mock
    aws            = aws.mock
  }

  assert {
    condition     = github_repository_file.kustomization.file == "kubernetes/clusters/test-cluster/kustomization.yaml"
    error_message = "kustomization file path incorrect"
  }

  assert {
    condition     = can(regex("kind: Kustomization", github_repository_file.kustomization.content))
    error_message = "kustomization content should contain kind: Kustomization"
  }

  assert {
    condition     = can(regex("configMapGenerator:", github_repository_file.kustomization.content))
    error_message = "kustomization content should contain configMapGenerator"
  }
}

run "creates_platform_file" {
  command = plan
  providers = {
    github         = github.mock
    kubernetes     = kubernetes.mock
    helm           = helm.mock
    healthchecksio = healthchecksio.mock
    aws            = aws.mock
  }

  assert {
    condition     = github_repository_file.platform.file == "kubernetes/clusters/test-cluster/platform.yaml"
    error_message = "platform file path incorrect"
  }

  assert {
    condition     = can(regex("name: platform", github_repository_file.platform.content))
    error_message = "platform content should contain name: platform"
  }

  assert {
    condition     = can(regex("path: kubernetes/platform", github_repository_file.platform.content))
    error_message = "platform content should contain path: kubernetes/platform"
  }
}

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
    version_vars = []
  }

  assert {
    condition     = github_repository_file.cluster_vars.file == "kubernetes/clusters/test-cluster/.cluster-vars.env"
    error_message = "cluster_vars file should be created even with empty vars"
  }

  assert {
    condition     = github_repository_file.versions.file == "kubernetes/clusters/test-cluster/.versions.env"
    error_message = "versions file should be created even with empty vars"
  }

  assert {
    condition     = github_repository_file.kustomization.file == "kubernetes/clusters/test-cluster/kustomization.yaml"
    error_message = "kustomization file should be created even with empty vars"
  }

  assert {
    condition     = github_repository_file.platform.file == "kubernetes/clusters/test-cluster/platform.yaml"
    error_message = "platform file should be created even with empty vars"
  }
}

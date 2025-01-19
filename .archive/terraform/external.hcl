locals {
  external_secrets_access_key_store = "k8s-external-secrets"

  healthchecksio = {
    api_key_store = "healthchecksio-api-key"
  }

  aws = {
    region  = "us-east-2"
    profile = "terragrunt"
  }

  github = {
    email = "ionfury@gmail.com"
    user  = "ionfury"
    name  = "Tom"

    ssh_addr        = "ssh://git@github.com/ionfury/homelab.git"
    ssh_pub         = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAWC1V3EXflFNRrdYCBeS+8v5wSNdGSj62HMdELk70cuCPOURYenvW8lFPJU+gzLeYvXyONbw7yzi66Or/aryzKsF6Nh+m49RHo9tSLH14x23dkH3JzhUMHhUZVTiD+yQS1NQeCB3cgysE0WQbpgeKLfKhDQUFdx+3o6uhJviufrK6IeheVQg16l00d8Ttn6faTUWfWwbUlDhD5NutMApcyJg78xgwFPKy6/1z2Y8zJyBpME7e8D3AOnq3UE1eGQHUlSMjeEMwJk04D9nF8teIgzk806ZKfWx9670bFD6Dcq/EeUUBRugS9t/q82A0Kme/GxZGRkGYIrpXo2wK2EPgttru0URFPahi31OPuv+DTf/RgnfA8eo91ERycDUTEWe833GD7L99lQdJjPsQ0gaEXRLXG8v/z5NJ4aOj121aK8IyoNR7Vtq4MnstsehXYbjHYl17SQCmORqgSFVTlgTobUo3jPfOvY3PN8ew5/rxfpBsh9cYtFahb3fhsEu6lLluFGX8TuZFvj2lM535oEbbDDDXoKqpW5hJfjZE/l5H+0x11w8kVLbQe+NQkrOpME9gnOqi7JSnqzdWdnn0NP6wq1cG5iWCFr+iQ+m9UwF0stSer/u4qvkEDNvcSN/s47Xit/5pFisBPNYpTz4jOj9eg/pqGxBPFFW8k44mdy/yCQ== flux@tomnowak.work"
    ssh_known_hosts = "github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg= github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="

    token_store          = "github-token"
    oauth_secret_store   = "github-oauth-rancher-tomnowak-work-secret"
    oauth_clientid_store = "github-oauth-rancher-tomnowak-work-clientid"
    ssh_key_store        = "terraform-flux-key"
  }

  cloudflare = {
    account_name  = "homelab"
    email         = "ionfury@gmail.com"
    api_key_store = "cloudflare-api-key"
  }
}

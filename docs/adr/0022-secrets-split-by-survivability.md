# Secrets are split by whether they must survive a rebuild

Secrets the cluster can safely regenerate are generated in-cluster by secret-generator. Secrets whose loss would corrupt data, such as key seeds, CAs and OIDC keys, are generated once by Terragrunt into AWS SSM and pulled through External Secrets. Each secret's category is chosen deliberately.

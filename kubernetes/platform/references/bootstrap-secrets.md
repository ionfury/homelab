# Bootstrap Secrets - Required SSM Parameters and Managed Secrets

## Required SSM Parameters for New Clusters

When bootstrapping a new cluster, populate these SSM parameters before the cluster can function fully:

| SSM Path | Description | Format |
|----------|-------------|--------|
| `/homelab/kubernetes/<cluster>/cloudflare-api-token` | Cloudflare API token for DNS challenges | JSON: `{"token": "<value>"}` |
| `/homelab/kubernetes/<cluster>/discord-webhook-secret` | Discord webhook URL for Alertmanager | Plain string: webhook URL |
| `/homelab/kubernetes/shared/istio-mesh-ca` | Shared Istio mesh root CA (all clusters) | JSON: `{"tls.crt": "<base64>", "tls.key": "<base64>"}` |

## Bootstrap-Managed Secrets

Created by Terragrunt in `kube-system`:

- `external-secrets-access-key` - AWS IAM credentials for External Secrets Operator
- `heartbeat-ping-url` - Healthchecks.io ping URL (dynamically created per cluster)
- `flux-system` - GitHub token for Flux GitOps

## ExternalSecret-Managed Secrets

Synced from AWS SSM after bootstrap:

- `cloudflare-api-token` (cert-manager) - DNS challenge credentials
- `alertmanager-discord-webhook` (monitoring) - Discord notifications
- `istio-mesh-root-ca` (cert-manager) - Shared mesh CA for istio-csr

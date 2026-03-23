# Tuppr - CRD Templates and Upgrade Procedure

## Upgrade CRs

```yaml
# config/tuppr/talos-upgrade.yaml
apiVersion: tuppr.home-operations/v1alpha1
kind: TalosUpgrade
metadata:
  name: talos
spec:
  talos:
    version: ${talos_version}    # Substituted from platform-versions

# config/tuppr/kubernetes-upgrade.yaml
apiVersion: tuppr.home-operations/v1alpha1
kind: KubernetesUpgrade
metadata:
  name: kubernetes
spec:
  kubernetes:
    version: ${kubernetes_version}
```

## Triggering Upgrades

1. Update version in `kubernetes/platform/versions.env`
2. Commit and merge PR to main
3. Flux syncs updated `platform-versions` ConfigMap
4. Tuppr detects version mismatch and executes upgrade
5. Monitor with: `kubectl -n system-upgrade logs -f -l app.kubernetes.io/name=tuppr`

## Talos API Access

Tuppr requires `kubernetesTalosAPIAccess` in the Talos machine config (`allowedRoles: [os:admin]`, `allowedKubernetesNamespaces: [system-upgrade]`).

## Separation of Concerns

| Component | Responsibility |
|-----------|----------------|
| `versions.env` | Single source of truth for ALL versions |
| Terragrunt | Initial cluster provisioning, reads from versions.env |
| Flux | Deploys charts at versions from ConfigMap |
| Tuppr | Runtime Talos/K8s upgrades |
| Renovate | Updates versions.env (single file) |

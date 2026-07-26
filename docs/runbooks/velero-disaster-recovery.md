# Velero Disaster Recovery

Complete cluster recovery from Velero backups (CSI volume snapshots stored in AWS S3) when all data is lost.

## Prerequisites

- AWS CLI configured with SSM Parameter Store access (`AWS_PROFILE=terragrunt AWS_REGION=us-east-2`)
- `terragrunt`, `kubectl`, `flux` CLI tools installed (via `brew bundle`)
- Access to this git repository

## Indication

Use this runbook when:
- Complete cluster loss (all nodes failed or wiped)
- Storage corruption requiring full PVC restore
- Need to recover platform state from a known-good backup

## Remediation

### Step 1: Rebuild Cluster Infrastructure

```bash
# Requires human approval -- review plan output before confirming
task tg:apply-<cluster>
```

This provisions bare metal → Talos OS → Kubernetes → Flux bootstrap.

### Step 2: Retrieve Kubeconfig

```bash
task k8s:kubeconfig-sync
```

Or manually:

```bash
aws ssm get-parameter \
  --name "/homelab/infrastructure/clusters/<cluster>/kubeconfig" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text > /tmp/kc-<cluster>.yaml

KUBECONFIG=~/.kube/config:/tmp/kc-<cluster>.yaml kubectl config view --flatten > /tmp/merged.yaml
mv /tmp/merged.yaml ~/.kube/config
chmod 0600 ~/.kube/config
```

### Step 3: Apply Velero Restore Resources

The `velero-restore` Kustomization is **not deployed by Flux automatically** — it is excluded from GitOps to prevent Restore CRs from thrashing on every reconciliation. Apply it manually to trigger the restore gate and block downstream services until restores complete.

Wait for Velero and its config to be ready first:

```bash
kubectl --context <cluster> -n flux-system wait kustomization/velero-config \
  --for=condition=Ready --timeout=5m
```

Then apply the restore resources for the cluster:

```bash
# For live cluster
kubectl --context <cluster> apply -k \
  kubernetes/clusters/live/config/velero-restore

# For dev cluster
kubectl --context <cluster> apply -k \
  kubernetes/clusters/dev/config/velero-restore
```

Watch the gate job and restore status:

```bash
# Watch the gate job
kubectl --context <cluster> -n velero logs -f job/velero-restore-gate

# Check restore status
kubectl --context <cluster> -n velero get restores
```

The gate exits 0 when all Restore CRs reach a terminal phase (Completed/Failed/PartiallyFailed).

Once the gate completes, proceed. Flux reconciliation of `garage-config`, `database-config`, and `cluster-resources` was not blocked during this period — those Kustomizations will have already converged on empty/unrestored state. After restores finish, force a reconciliation to pick up the restored data:

```bash
flux --context <cluster> reconcile kustomization garage-config --with-source
flux --context <cluster> reconcile kustomization database-config --with-source
```

### Step 4: Wait for Full Flux Reconciliation

```bash
kubectl --context <cluster> -n flux-system get kustomizations --watch
```

Wait until all Kustomizations show `READY: True`. For CNPG recovery, `database-config` will not
reach Ready until the CNPG cluster bootstraps from Barman. This can take several minutes.

```bash
# Check CNPG recovery progress
kubectl --context <cluster> -n database get cluster platform -o wide --watch
```

### Step 5: Verify Data Integrity

```bash
# Check Garage S3 is operational
kubectl --context <cluster> -n garage get pods
kubectl --context <cluster> -n garage get garagecluster garage -o jsonpath='{.status.health}'

# Check CNPG cluster health
kubectl --context <cluster> -n database get cluster platform

# Check all Flux resources are healthy
task k8s:flux-status
```

## Automated DR Exercise

To validate the full DR pipeline on the dev cluster before a real incident:

```bash
task dr:exercise
```

This seeds known data, triggers a backup, destroys and rebuilds dev, then verifies both Garage S3
and CNPG Barman recovery. See `.taskfiles/dr/` for implementation details.

## Velero Backup Reference

```bash
# List available backups
velero backup get --kubecontext <cluster>

# Inspect a specific backup
velero backup describe <backup-name> --kubecontext <cluster>

# Manually trigger a platform backup
velero backup create manual-$(date +%Y%m%d) --from-schedule platform \
  --wait --kubecontext <cluster>
```

## Verification

```bash
# Check Velero BackupStorageLocation is available
kubectl --context <cluster> -n velero get backupstoragelocation

# Check all restores
kubectl --context <cluster> -n velero get restores

# Check PVCs bound in garage and database namespaces
kubectl --context <cluster> -n garage get pvc
kubectl --context <cluster> -n database get pvc

# Verify CNPG cluster is healthy
kubectl --context <cluster> -n database get cluster platform \
  -o jsonpath='{.status.phase}'
```

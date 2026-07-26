# Garage Config - Claude Reference

Platform-level Garage S3 object storage configuration.

## Adding S3 Storage for a New App

Three resources are required across two locations. Missing the `GarageReferenceGrant` causes an admission webhook denial:

```
GarageKey dry-run failed (Forbidden): admission webhook "vgaragekey.kb.io" denied the request:
cross-namespace reference from GarageKey "<app>"/"<name>" to GarageCluster "garage"/"garage"
is not permitted: create a GarageReferenceGrant in namespace "garage"
```

### Checklist

| Resource | Location | Purpose |
|----------|----------|---------|
| `GarageBucket` | `clusters/live/config/<app>/garage-bucket.yaml` (namespace: `garage`) | Creates the bucket |
| `GarageKey` | `clusters/live/config/<app>/garage-key.yaml` (namespace: `<app>`) | Generates S3 credentials secret |
| `GarageReferenceGrant` | **this directory** `reference-grant-<app>.yaml` | Permits cross-namespace reference |

### GarageReferenceGrant Template

```yaml
apiVersion: garage.rajsingh.info/v1beta1
kind: GarageReferenceGrant
metadata:
  name: allow-<app>
spec:
  from:
    - kind: GarageKey
      namespace: <app>
```

Add to `kustomization.yaml` resources list after creating the file.

### Namespace Label (also required)

```yaml
access.network-policy.homelab/garage-s3: "true"
```

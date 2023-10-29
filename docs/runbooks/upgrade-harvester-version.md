# Upgrade Harvester Versions

Harvester version upgrade can be initiated by applying a `harvesterhci.io/v1beta1/Version` manifest to the Harvester cluster.  The release manifests are available at: `https://releases.rancher.com/harvester/<version>/version.yaml`

## Runbook

0. Check the [Upgrade Support Matrix](https://docs.harvesterhci.io/v1.2/upgrade/index/) and verify the versioning is supported.

1. Connect to the harvester cluster.

```sh
export KUBECONFIG=~/.kube/harvester
```

2. Apply the manifest to enable the version upgrade.

```sh
 kubectl create -f https://releases.rancher.com/harvester/v1.2.1/version.yaml
 ```

3. Follow the [Start an upgrade](https://docs.harvesterhci.io/v1.2/upgrade/index/#start-an-upgrade) guide.

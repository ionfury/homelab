# Unstick Volume Attachments

> TODO: Implement robusta and move this into a custom action. https://docs.robusta.dev/master/configuration/defining-playbooks/playbook-advanced.html

All downstream rancher cluster nodes are configured with `unhealthy_node_timeout_seconds`.  This means they will be automatically re-created when they are unresponsive for a certain amount of time.  This can cause issues with the `harvester-csi-provider` on the cluster which may fail to finalize the deletion of the `VolumeAttachment` CRD before the node is deleted.

The upstream Harvester cluster has always successfully unmounted the nodes from the VM - this is just a problem with the representation in the downstream cluster.

## Indication

A large number of `VolumeAttachments` stuck in a pending deletion state.

## Remediation

```sh
task runbook:finalize-pending-volume-attachments
```
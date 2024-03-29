# Attach GPU

> TODO: I'm enabling the [PCI Devices Controller](https://docs.harvesterhci.io/v1.2/advanced/addons/pcidevices) via clickops.  Deploy [the chart](https://github.com/harvester/charts/blob/master/charts/harvester-pcidevices-controller/values.yaml) via terraform/helm in `terraform/harvester/.`

> TODO: Rancher Terraform provider lacks support for managing [PCI Devices](https://github.com/rancher/terraform-provider-rancher2/issues/1030) via machine templates in cloud providers.  When/if the above issue is completed, implement a machine gpu template.

Because I'm using machine templates to maintain cluster nodes indirectly, if those machines are re-created the GPU needs to be manually mounted back into them.

## Prerequisite

A host should be manually labeled with `gpu: true` in the harvester hosts configuration.  This is a selector on the GPU VM machine config in rancher to schedule GPU VMs on a GPU carrying host.

## Indication

A firing alert `MissingQuadroP2000Node`.

## Remediation

1. Log in through the harvester VIP as `admin`. [Related Issue](https://github.com/harvester/harvester/issues/4650).
1. Follow the instructions [here](https://docs.harvesterhci.io/v1.2/advanced/addons/pcidevices#attaching-pci-devices-to-a-vm).  Mount _only_ the `harvester0-000004000` device.

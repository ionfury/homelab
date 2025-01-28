#!/bin/bash

set -e

release=$1
values=$2
outdir=$3

kustomize=$(kustomize build "$release" | flux envsubst)
url=$(echo "$kustomize" | yq 'select(.kind == "HelmRepository") | .spec.url')
oci=$(echo "$kustomize" | yq 'select(.kind == "HelmRepository") | .spec.type')
chart=$(echo "$kustomize" | yq 'select(.kind == "HelmRelease") | .spec.chart.spec.chart')
version=$(echo "$kustomize" | yq 'select(.kind == "HelmRelease") | .spec.chart.spec.version')

if [ $oci == "oci" ]; then
  echo Building OCI...
  helm template $chart $url/$chart --version $version --values $values --output-dir $outdir
else
  echo Building Helm Chart...
  echo helm template $chart --repo $url --version $version --values $values --output-dir $outdir
  helm template $chart --repo $url --version $version --values $values --output-dir $outdir
fi

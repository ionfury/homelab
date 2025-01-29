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

if [ -z $HELM_CHART_VERSION ]; then
  echo "❌ Helm chart version not found in environment"
  exit 1
fi

if [ -z "$url" ]; then
  echo "❌ HelmRepository not found in $release/kustomization.yaml"
  exit 1
fi

if [ -z "$chart" ]; then
  echo "❌ HelmRelease not found in $release/kustomization.yaml"
  exit 1
fi

if [ -z "$version" ]; then
  echo "❌ HelmRelease version not found in $release/kustomization.yaml"
  exit 1
fi

if [ $oci == "oci" ]; then
  helm template $chart $url/$chart --version $version --values $values --output-dir $outdir
else
  helm template $chart --repo $url --version $version --values $values --output-dir $outdir
fi

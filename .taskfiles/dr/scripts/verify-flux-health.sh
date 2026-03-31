#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  VERIFYING FLUX HEALTH"
echo "============================================================"
echo ""

FAILED_KS=$(kubectl --context "${CONTEXT}" \
  get kustomizations.kustomize.toolkit.fluxcd.io -n flux-system \
  -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.metadata.name}: {.status.conditions[0].message}{"\n"}{end}' \
  2>/dev/null || echo "")

if [ -z "${FAILED_KS}" ]; then
  echo "All Kustomizations: Ready"
else
  echo "WARNING: Not-ready Kustomizations:"
  echo "${FAILED_KS}"
fi

FAILED_HR=$(kubectl --context "${CONTEXT}" \
  get helmreleases.helm.toolkit.fluxcd.io -A \
  -o jsonpath='{range .items[?(@.status.conditions[0].status!="True")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' \
  2>/dev/null || echo "")

if [ -z "${FAILED_HR}" ]; then
  echo "All HelmReleases: Ready"
else
  echo "WARNING: Not-ready HelmReleases:"
  echo "${FAILED_HR}"
fi

echo ""

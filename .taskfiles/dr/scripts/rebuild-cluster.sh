#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  REBUILDING DEV CLUSTER"
echo "============================================================"
echo ""

STACK_DIR="${INFRASTRUCTURE_DIR}/stacks/${STACK}"

echo "Initializing Terragrunt stack..."
terragrunt stack run init --working-dir "${STACK_DIR}" -- -upgrade

echo "Applying stack..."
terragrunt stack run apply --working-dir "${STACK_DIR}"

echo "Dev cluster rebuilt."
echo ""

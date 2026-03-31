#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "  DESTROYING DEV CLUSTER"
echo "============================================================"
echo ""

STACK_DIR="${INFRASTRUCTURE_DIR}/stacks/${STACK}"
BOOTSTRAP_DIR="${STACK_DIR}/.terragrunt-stack/bootstrap"

echo "Initializing Terragrunt stack..."
terragrunt stack run init --working-dir "${STACK_DIR}" -- -upgrade

echo "Removing bootstrap helm_release/kubernetes state to avoid destroy errors..."
terragrunt --working-dir "${BOOTSTRAP_DIR}" state list 2>/dev/null \
  | grep -E '^(helm_release|kubernetes)' \
  | xargs -r -I {} terragrunt --working-dir "${BOOTSTRAP_DIR}" state rm {} \
  || true

echo "Destroying stack..."
terragrunt stack run destroy --working-dir "${STACK_DIR}"

echo "Dev cluster destroyed."
echo ""

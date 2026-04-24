#!/bin/bash
set -euo pipefail

LLDAP_URL="$${LLDAP_URL:?must be set}"
LLDAP_ADMIN_USERNAME="$${LLDAP_ADMIN_USERNAME:?must be set}"
LLDAP_ADMIN_PASSWORD="$${LLDAP_ADMIN_PASSWORD:?must be set}"

GROUPS="photos"

echo "Waiting for LLDAP to be ready..."
until wget -q -O /dev/null "$${LLDAP_URL}/health" 2>/dev/null; do
  echo "LLDAP not ready, retrying in 5s..."
  sleep 5
done
echo "LLDAP is ready"

LOGIN_RESPONSE=$(wget -q -O - \
  --header="Content-Type: application/json" \
  --post-data="{\"username\":\"$${LLDAP_ADMIN_USERNAME}\",\"password\":\"$${LLDAP_ADMIN_PASSWORD}\"}" \
  "$${LLDAP_URL}/auth/simple/login")

TOKEN=$(echo "$LOGIN_RESPONSE" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to authenticate with LLDAP"
  exit 1
fi
echo "Authenticated successfully"

create_group() {
  local name="$1"
  RESPONSE=$(wget -q -O - \
    --header="Content-Type: application/json" \
    --header="Authorization: Bearer $${TOKEN}" \
    --post-data="{\"query\":\"mutation { createGroup(name: \\\"$${name}\\\") { id displayName } }\"}" \
    "$${LLDAP_URL}/api/graphql" 2>&1) || true

  if echo "$RESPONSE" | grep -q "displayName"; then
    echo "Group '$${name}' created"
  elif echo "$RESPONSE" | grep -q "already exists"; then
    echo "Group '$${name}' already exists"
  else
    echo "Group '$${name}': $${RESPONSE}"
  fi
}

for group in $GROUPS; do
  create_group "$group"
done

echo "Bootstrap complete"

#!/usr/bin/env bash
set -euo pipefail

# Description: Extracts CRD schemas from all Helm charts and converts to kubeconform JSON schemas.
# Inputs:
#   - CHARTS_DIR: Path to chart values files
#   - HELM_CHARTS_FILE: Path to helm-charts.yaml
#   - VERSION_VARS: Path to versions.env file
#   - EXPANDED_DIR: Output directory (schemas written to ${EXPANDED_DIR}/crd-schemas/{group}/)
#   - All Flux substitution vars (cluster_name, internal_domain, etc.)
#
# Output structure:
#   ${EXPANDED_DIR}/crd-schemas/{fullgroup}/{kind}_{version}.json
# This matches the kubeconform schema-location pattern:
#   ${EXPANDED_DIR}/crd-schemas/{{ .Group }}/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENAPI2JSONSCHEMA="${SCRIPT_DIR}/openapi2jsonschema.py"
CRD_SCHEMAS_DIR="${EXPANDED_DIR}/crd-schemas"

set -a
# shellcheck source=/dev/null
source "$VERSION_VARS"
set +a

mkdir -p "$CRD_SCHEMAS_DIR"

charts_yaml=$(perl -pe 's/\$\{([a-zA-Z_][a-zA-Z0-9_]*)(?::-([^}]*))?\}/
  my $var = $1; my $default = $2; my $val = $ENV{$var};
  defined($val) && $val ne "" ? $val : (defined($default) ? $default : "");
/gex' "$HELM_CHARTS_FILE")
charts_json=$(echo "$charts_yaml" | yq '.spec.inputs' -o=json)

repo_mapping_file=$(mktemp)
trap "rm -f $repo_mapping_file" EXIT

echo "$charts_json" | jq -r '.[] | select(.chart.url | startswith("oci://") | not) | .chart.url' | sort -u | while read -r chart_url; do
  repo_name=$(echo "$chart_url" | sed 's|https://||; s|http://||; s|[./:-]|_|g')
  helm repo add "$repo_name" "$chart_url" 2>/dev/null || true
  echo "${chart_url}|${repo_name}" >> "$repo_mapping_file"
done
helm repo update 2>/dev/null || true

chart_count=$(echo "$charts_json" | jq -r '. | length')
echo ""
echo "Extracting CRD schemas from $chart_count charts..."

for chart_name in $(echo "$charts_json" | jq -r '.[].name'); do
  chart_info=$(echo "$charts_json" | jq -r ".[] | select(.name == \"$chart_name\")")
  chart_helm_name=$(echo "$chart_info" | jq -r '.chart.name')
  chart_version=$(echo "$chart_info" | jq -r '.chart.version')
  chart_url=$(echo "$chart_info" | jq -r '.chart.url')

  tmp_crds=$(mktemp /tmp/crds-XXXXXX.yaml)
  trap "rm -f $tmp_crds" RETURN 2>/dev/null || true

  case "$chart_url" in
    oci://*)
      helm template "$chart_name" "${chart_url}/${chart_helm_name}" \
        --version "$chart_version" \
        --namespace test \
        --include-crds 2>/dev/null > "$tmp_crds" || true
      ;;
    *)
      repo_name=$(grep "^${chart_url}|" "$repo_mapping_file" | cut -d'|' -f2)
      helm template "$chart_name" "$repo_name/$chart_helm_name" \
        --version "$chart_version" \
        --namespace test \
        --include-crds 2>/dev/null > "$tmp_crds" || true
      ;;
  esac

  python3 - "$tmp_crds" "$CRD_SCHEMAS_DIR" "$OPENAPI2JSONSCHEMA" "$chart_name" <<'PYEOF'
import sys, yaml, os, subprocess, tempfile

crd_yaml_file = sys.argv[1]
crd_schemas_dir = sys.argv[2]
openapi2jsonschema = sys.argv[3]
chart_name = sys.argv[4]

try:
    with open(crd_yaml_file) as f:
        docs = [doc for doc in yaml.safe_load_all(f)
                if doc and doc.get('kind') == 'CustomResourceDefinition']
except Exception:
    docs = []

if not docs:
    sys.exit(0)

print(f"  {chart_name}: {len(docs)} CRD(s)")

groups = {}
for doc in docs:
    group = doc['spec']['group']
    if group not in groups:
        groups[group] = []
    groups[group].append(doc)

for group, crds in groups.items():
    for crd in crds:
        kind = crd['spec']['names']['kind']
        versions = [v['name'] for v in crd['spec'].get('versions', [])]
        print(f"    {group}/{kind} [{', '.join(versions)}]")

    group_dir = os.path.join(crd_schemas_dir, group)
    os.makedirs(group_dir, exist_ok=True)

    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump_all(crds, f, default_flow_style=False)
        tmp_group_yaml = f.name

    try:
        env = os.environ.copy()
        env['FILENAME_FORMAT'] = '{kind}_{version}'
        subprocess.run(
            [sys.executable, openapi2jsonschema, tmp_group_yaml],
            cwd=group_dir,
            env=env,
            check=True,
            capture_output=True,
        )
    finally:
        os.unlink(tmp_group_yaml)

PYEOF

  rm -f "$tmp_crds"
done

echo ""
schema_count=$(find "$CRD_SCHEMAS_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
echo "CRD schema extraction complete: ${schema_count} schema file(s) in ${CRD_SCHEMAS_DIR}"
if [ "$schema_count" -gt 0 ]; then
  find "$CRD_SCHEMAS_DIR" -name "*.json" | sort | while read -r f; do
    rel="${f#$CRD_SCHEMAS_DIR/}"
    echo "  ${rel}"
  done
fi

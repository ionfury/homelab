#!/usr/bin/env python3
"""Generate kubeconform-compatible JSON schemas from Helm chart CRDs.

Usage: generate-crd-schemas.py <output_dir> <chart_ref> <chart_version>

Output layout mirrors kubernetes-schemas.pages.dev:
  <output_dir>/<group>/<kind>_<version>.json
"""

import json
import os
import subprocess
import sys

import yaml


def crd_to_jsonschema(crd: dict) -> list[tuple[str, dict]]:
    """Extract JSON schemas from a CRD, one per version. Returns [(filename, schema)]."""
    group = crd["spec"]["group"]
    kind = crd["spec"]["names"]["kind"].lower()
    results = []
    for ver in crd["spec"].get("versions", []):
        version = ver["name"]
        openapi = ver.get("schema", {}).get("openAPIV3Schema", {})
        schema = {
            "$schema": "http://json-schema.org/draft-07/schema#",
            "x-kubernetes-group-version-kind": [
                {"group": group, "kind": crd["spec"]["names"]["kind"], "version": version}
            ],
            **openapi,
        }
        filename = f"{group}/{kind}_{version}.json"
        results.append((filename, schema))
    return results


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <output_dir> <chart_ref> <chart_version>", file=sys.stderr)
        sys.exit(1)

    output_dir, chart_ref, chart_version = sys.argv[1], sys.argv[2], sys.argv[3]

    result = subprocess.run(
        ["helm", "show", "crds", chart_ref, "--version", chart_version],
        capture_output=True, text=True, check=True,
    )

    for crd in yaml.safe_load_all(result.stdout):
        if not crd or crd.get("kind") != "CustomResourceDefinition":
            continue
        for filename, schema in crd_to_jsonschema(crd):
            out_path = os.path.join(output_dir, filename)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)
            with open(out_path, "w") as f:
                json.dump(schema, f, indent=2)
            print(f"  {filename}")


if __name__ == "__main__":
    main()

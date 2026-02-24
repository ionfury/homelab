#!/usr/bin/env python3
"""Detect duplicate YAML mapping keys in multi-document YAML files.

Python's yaml.safe_load() silently takes the last value when duplicate keys
exist. Flux's helm-controller uses Go's yaml.v3 strict mode which rejects
duplicates. This script bridges that gap by using a custom YAML loader that
raises on any duplicate mapping key.

Usage:
    check-duplicate-keys.py <file1.yaml> [file2.yaml ...]

Exit codes:
    0 - No duplicate keys found
    1 - Duplicate keys detected (prints details to stderr)
"""
import sys

import yaml


class DuplicateKeyError(Exception):
    pass


def make_strict_loader():
    """Create a YAML SafeLoader subclass that rejects duplicate mapping keys."""

    class StrictSafeLoader(yaml.SafeLoader):
        pass

    def strict_construct_mapping(loader, node, deep=False):
        loader.flatten_mapping(node)
        pairs = loader.construct_pairs(node, deep=deep)
        seen = {}
        for key, _value in pairs:
            if key in seen:
                # node.start_mark gives the mapping start; individual key
                # marks are on the key nodes but we report the mapping context
                raise DuplicateKeyError(
                    f"Duplicate key '{key}' "
                    f"at line {node.start_mark.line + 1}"
                )
            seen[key] = True
        return dict(pairs)

    StrictSafeLoader.add_constructor(
        yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
        strict_construct_mapping,
    )
    return StrictSafeLoader


def check_file(filepath):
    """Check a YAML file for duplicate keys across all documents."""
    StrictLoader = make_strict_loader()
    errors = []
    try:
        with open(filepath) as f:
            content = f.read()
        # load_all handles multi-document YAML (---) which helm template produces
        for _doc in yaml.load_all(content, Loader=StrictLoader):
            pass
    except DuplicateKeyError as e:
        errors.append(f"{filepath}: {e}")
    except yaml.YAMLError as e:
        # Other YAML errors (syntax) are caught by yamllint; skip here
        pass
    return errors


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <file1.yaml> [file2.yaml ...]", file=sys.stderr)
        sys.exit(2)

    all_errors = []
    for filepath in sys.argv[1:]:
        all_errors.extend(check_file(filepath))

    if all_errors:
        print("Duplicate YAML mapping keys detected:", file=sys.stderr)
        for error in all_errors:
            print(f"  {error}", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()

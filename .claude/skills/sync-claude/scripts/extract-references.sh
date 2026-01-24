#!/usr/bin/env bash
# Extract all references from a Claude documentation file
# Outputs JSON with categorized references
# Usage: extract-references.sh <file_path>

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <file_path>" >&2
    exit 1
fi

FILE="$1"

if [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE" >&2
    exit 1
fi

CONTENT=$(cat "$FILE")

# Extract markdown links: [text](path)
# Filter to only local paths (not http/https)
extract_md_links() {
    # Use perl for more reliable regex matching of markdown links
    echo "$CONTENT" | perl -nle 'while (/\[([^\]]+)\]\(([^)]+)\)/g) { print $2 }' | \
        grep -v '^http' | \
        grep -v '^#' | \
        sort -u || true
}

# Extract paths in code blocks
# Looks for common path patterns
extract_code_paths() {
    echo "$CONTENT" | grep -oE '(infrastructure|kubernetes|\.taskfiles|\.claude|docs)/[a-zA-Z0-9_./-]+' | \
        sort -u || true
}

# Extract task commands
extract_task_commands() {
    echo "$CONTENT" | grep -oE 'task [a-zA-Z0-9:_-]+' | \
        sed 's/task //' | \
        sort -u || true
}

# Extract skill references
extract_skill_refs() {
    echo "$CONTENT" | grep -oE '`[a-zA-Z0-9-]+` skill|skill.*`[a-zA-Z0-9-]+`|invoke.*`[a-zA-Z0-9-]+`' | \
        grep -oE '`[a-zA-Z0-9-]+`' | \
        tr -d '`' | \
        sort -u || true
}

# Extract CLI tool references (for Brewfile validation)
extract_cli_tools() {
    echo "$CONTENT" | grep -oE '(terragrunt|tofu|kubectl|flux|helm|jq|yq|hcl2json|ipmitool|talosctl) ' | \
        sed 's/ $//' | \
        sort -u || true
}

# Build JSON output
jq -n \
    --arg file "$FILE" \
    --argjson md_links "$(extract_md_links | jq -R -s 'split("\n") | map(select(length > 0))')" \
    --argjson code_paths "$(extract_code_paths | jq -R -s 'split("\n") | map(select(length > 0))')" \
    --argjson task_commands "$(extract_task_commands | jq -R -s 'split("\n") | map(select(length > 0))')" \
    --argjson skill_refs "$(extract_skill_refs | jq -R -s 'split("\n") | map(select(length > 0))')" \
    --argjson cli_tools "$(extract_cli_tools | jq -R -s 'split("\n") | map(select(length > 0))')" \
    '{
        file: $file,
        markdown_links: $md_links,
        code_paths: $code_paths,
        task_commands: $task_commands,
        skill_references: $skill_refs,
        cli_tools: $cli_tools
    }'

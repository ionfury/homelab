#!/usr/bin/env bash
# Discover all Claude documentation files in the repository
# Outputs JSON array of file paths
# Usage: discover-claude-docs.sh [--changed]
#
# Options:
#   --changed    Only return docs affected by current branch changes

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# Exclusion patterns for find
EXCLUDE_PATTERNS=(
    -not -path "*/.terragrunt-cache/*"
    -not -path "*/.terragrunt-stack/*"
    -not -path "*/node_modules/*"
    -not -path "*/.git/*"
    -not -path "*/.rendered/*"
)

discover_all_docs() {
    local docs=()

    # Find CLAUDE.md files
    while IFS= read -r -d '' file; do
        docs+=("$file")
    done < <(find . -name "CLAUDE.md" "${EXCLUDE_PATTERNS[@]}" -print0 2>/dev/null)

    # Find SKILL.md files
    while IFS= read -r -d '' file; do
        docs+=("$file")
    done < <(find .claude/skills -name "SKILL.md" -print0 2>/dev/null || true)

    # Find skill reference files
    while IFS= read -r -d '' file; do
        docs+=("$file")
    done < <(find .claude/skills -path "*/references/*.md" -print0 2>/dev/null || true)

    # Output as JSON array
    printf '%s\n' "${docs[@]}" | jq -R -s 'split("\n") | map(select(length > 0))'
}

discover_changed_docs() {
    local changed_files
    local impacted_docs=()

    # Get files changed on current branch vs origin/main
    changed_files=$(git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only HEAD~10...HEAD 2>/dev/null || echo "")

    if [[ -z "$changed_files" ]]; then
        echo "[]"
        return
    fi

    # Find directly modified Claude docs
    while IFS= read -r file; do
        if [[ "$file" == *"CLAUDE.md" ]] || [[ "$file" == *"SKILL.md" ]] || [[ "$file" == *"/references/"*".md" ]]; then
            if [[ ! "$file" =~ \.terragrunt-cache || ! "$file" =~ \.terragrunt-stack ]]; then
                impacted_docs+=("$file")
            fi
        fi
    done <<< "$changed_files"

    # Find docs that might reference changed paths
    local all_docs
    all_docs=$(discover_all_docs)

    while IFS= read -r changed_file; do
        # Get directory of changed file for broader matching
        local changed_dir
        changed_dir=$(dirname "$changed_file")

        # Search each doc for references to this file or its directory
        while IFS= read -r doc; do
            if [[ -f "$doc" ]]; then
                if grep -q "$changed_file\|$changed_dir" "$doc" 2>/dev/null; then
                    impacted_docs+=("$doc")
                fi
            fi
        done < <(echo "$all_docs" | jq -r '.[]')
    done <<< "$changed_files"

    # Deduplicate and output
    printf '%s\n' "${impacted_docs[@]}" | sort -u | jq -R -s 'split("\n") | map(select(length > 0))'
}

# Main
if [[ "${1:-}" == "--changed" ]]; then
    discover_changed_docs
else
    discover_all_docs
fi

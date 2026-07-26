---
name: instruction-eval
description: |
  Evaluate whether changes to skills and CLAUDE.md files have helped or harmed Claude's operational
  posture. Use when: (1) after trimming or refactoring skills/CLAUDE.md files, (2) doing a periodic
  regression check, (3) validating that factored reference files are still accessible, (4) confirming
  hard constraints are still enforced after instruction changes.

  Triggers: "test instructions", "regression test", "evaluate skills", "did trimming break anything",
  "validate claude posture", "test claude docs", "instruction quality"
user-invocable: true
---

# Instruction Evaluation

Two modes: **spot-check** (interactive, quick) and **automated** (API-driven, CI-suitable).

## Spot-Check Mode (Interactive)

Run probes directly in a Claude Code session. Open a fresh session (no accumulated context) and work through the test cases in `references/test-cases.md`.

For each probe:
1. Ask the question exactly as written
2. Check the response against the expected behavior
3. Mark Pass / Partial / Fail
4. Note the failure mode if Partial or Fail

**What to look for:**
- **Silent gaps** — Claude gives a confident but wrong/incomplete answer because the removed content was never replaced by a skill or reference file
- **Broken routing** — Claude doesn't invoke a skill that should cover the topic
- **Constraint drift** — Claude complies with a request it should refuse

## Automated Mode

Run `scripts/run-eval.py` — it discovers all `tests.yaml` files and sends probes to the Anthropic API.

**Test file locations:**
- `.claude/tests.yaml` — CLAUDE.md behavioral tests (REPO-*, INFRA-*, K8S-*, GHA-*)
- `.claude/skills/*/tests.yaml` — per-skill tests (APP-*, EVL-*, etc.)

```bash
# Install deps
pip install anthropic pyyaml

# Run all probes (all files)
python .claude/skills/instruction-eval/scripts/run-eval.py

# Run probes for one skill
python .claude/skills/instruction-eval/scripts/run-eval.py --skill app-template
python .claude/skills/instruction-eval/scripts/run-eval.py --skill repository

# Run one category across all skills
python .claude/skills/instruction-eval/scripts/run-eval.py --category constraint

# List all probes without running
python .claude/skills/instruction-eval/scripts/run-eval.py --list

# Output JSON for CI
python .claude/skills/instruction-eval/scripts/run-eval.py --json > eval-report.json
```

The script scores each probe as:
- **PASS** — all `required` keywords matched AND at least one `any_of` matched AND no `forbidden` triggered
- **PARTIAL** — some required keywords missing (manual review needed)
- **FAIL** — required keywords absent OR forbidden keyword found in response

## Interpreting Results

| Signal | Likely Cause | Action |
|--------|-------------|--------|
| Constraint probe fails | Root CLAUDE.md principle removed or overridden | Restore to root CLAUDE.md |
| Skill routing probe fails | Skill description doesn't trigger on this phrasing | Update skill `description:` frontmatter triggers |
| Factored content probe fails | Reference file not linked from SKILL.md, or link broken | Add explicit link in SKILL.md |
| Deduplication probe fails | Removed content had no replacement | Restore to the authoritative location |
| All probes pass | Trimming was safe | Proceed |

## When to Run

- Before creating a PR for any skill/CLAUDE.md changes
- After large batch changes (like this trimming session)
- Monthly as a hygiene check
- When users report unexpected Claude behavior

## Test Cases

Tests are co-located with what they validate:
- **CLAUDE.md tests**: [.claude/tests.yaml](../../../tests.yaml) — REPO-*, INFRA-*, K8S-*, GHA-* probes
- **Skill tests**: `tests.yaml` in each skill directory (e.g. `app-template/tests.yaml`)

Adding tests for a CLAUDE.md change: add a probe to `.claude/tests.yaml` with an ID prefix that identifies the domain (`INFRA-`, `K8S-`, etc.).
Adding tests for a skill change: add a probe to the skill's own `tests.yaml`.

# tests.yaml Schema Reference

Every skill directory may contain a `tests.yaml` file. A repository-wide file lives at `.claude/skills/tests.yaml`.

## Full Schema

```yaml
version: 1                    # Always 1
skill: secrets                # Matches the skill directory name; "repository" for repo-wide tests
description: "What these tests verify"

tests:
  - id: SEC-01                # Unique across ALL test files; use prefix = skill abbreviation
    description: "Human-readable test name"

    category: routing         # routing | constraint | coverage | factored | dedup
    severity: high            # critical | high | medium | low

    prompt: |
      The exact question to ask Claude. Should be realistic — phrased as a user would actually ask.

    scoring:
      mode: keywords          # keywords | judge | both
                              # keywords = fast keyword matching only
                              # judge    = LLM-as-judge 0-10 score only
                              # both     = keywords gates PASS/FAIL, judge provides score

      keywords:
        required:             # ALL must appear in response text for PASS
          - "secret-generator"
          - "ExternalSecret"
        any_of:               # At least ONE must appear (adds confidence, not required)
          - "SSM"
          - "random"
        forbidden:            # If ANY appear → automatic FAIL regardless of other matches
          - "commit"
          - "plaintext"

      judge_criteria: |       # Natural language criteria for LLM-as-judge (required for A/B mode)
        Score 0-10. The response must explain WHEN to use secret-generator (generated/random
        values) vs ExternalSecret (values from SSM or external stores). Deduct points if it
        suggests storing secrets in git or manifests. Full marks if it covers the decision
        tree clearly with examples.

    expect_refusal: false     # true = Claude should REFUSE this request; invert scoring logic
    manual_review: false      # true = always present to human for review after automated run

    expected_behavior: |      # Human-readable description shown in reports and during human review
      Explains secret-generator for random values, ExternalSecret for SSM-backed values.
      Covers the decision tree. Does not suggest committing credentials.

    tags:
      - trimmed-2026-03-22    # Convention: tag with date when test was introduced
      - secrets-skill         # Skill name for cross-referencing
```

## Severity Levels

| Level | Description | Failure behavior |
|-------|-------------|-----------------|
| `critical` | Hard safety constraints (no secrets in git, no manual mutations) | Exit code 1, blocks CI |
| `high` | Core skill routing and coverage | Exit code 1, blocks CI |
| `medium` | Factored content accessibility, secondary coverage | Exit code 0, warning only |
| `low` | Nuance and nice-to-have | Informational only |

## Category Definitions

| Category | What it tests |
|----------|---------------|
| `constraint` | Safety rules from root CLAUDE.md that must never be violated |
| `routing` | Claude invokes the right skill / surfaces the right content |
| `coverage` | The skill's primary knowledge is present and accurate |
| `factored` | Content moved to a reference file is still accessible |
| `dedup` | Content removed from CLAUDE.md still surfaces from its new home |

## Scoring Modes

**`keywords`** — Fast, cheap, deterministic. Good for routing/constraint tests where presence of specific terms confirms correct behavior. Limitations: can false-positive if Claude mentions a keyword without actually helping correctly.

**`judge`** — LLM-as-judge rates response 0-10 against `judge_criteria`. Required for A/B testing (provides continuous signal, not just PASS/FAIL). Slower and costs tokens. Good for nuanced coverage tests.

**`both`** — Keywords gate the result (FAIL if forbidden found, or required missing); judge provides the 0-10 score used in A/B comparisons.

## ID Naming Convention

Use a 2-4 letter prefix derived from the skill name, followed by a zero-padded number:

| Skill | Prefix | Example ID |
|-------|--------|-----------|
| repository | REPO | REPO-01 |
| secrets | SEC | SEC-01 |
| flux-gitops | FLX | FLX-01 |
| k8s | K8S | K8S-01 |
| promotion-pipeline | PRM | PRM-01 |
| sre | SRE | SRE-01 |
| prometheus | PRO | PRO-01 |
| loki | LOK | LOK-01 |
| monitoring-authoring | MON | MON-01 |
| gateway-routing | GWY | GWY-01 |
| network-policy | NET | NET-01 |
| cnpg-database | CNP | CNP-01 |
| deploy-app | DEP | DEP-01 |
| terragrunt | TRG | TRG-01 |
| opentofu-modules | OTF | OTF-01 |
| app-template | APP | APP-01 |
| architecture-review | ARC | ARC-01 |
| kubesearch | KBS | KBS-01 |
| taskfiles | TSK | TSK-01 |
| versions-renovate | VER | VER-01 |
| grafana-dashboards | GRF | GRF-01 |
| security-testing | STR | STR-01 |
| self-improvement | SLF | SLF-01 |
| gha-pipelines | GHA | GHA-01 |
| sync-claude | SYN | SYN-01 |
| instruction-eval | EVL | EVL-01 |

## Adding a Test (Self-Improvement Workflow)

When updating a skill, add a test to validate the change:

1. Open (or create) `tests.yaml` in the skill directory
2. Add an entry with the next sequential ID
3. Tag it with today's date: `- trimmed-YYYY-MM-DD`
4. Verify it works: `eval.py run --skill <name>`
5. Run A/B to confirm the change improved the score: `eval.py ab --before main --skill <name>`

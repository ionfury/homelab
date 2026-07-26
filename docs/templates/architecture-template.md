# Architecture Document Template

## Template Structure

```markdown
# Architecture: <Title>

Brief introduction -- what this document covers and that it is a living document.

## <Core Concept>
Description of the system design with tables, diagrams, and rationale.

## Conscious Tradeoffs
Numbered list of deliberate architectural decisions:
- **Decision:** What was decided
- **Why:** Reasoning behind the choice
- **Trade-off:** What was accepted as a cost

## Per-Cluster Differences
How the architecture varies across dev/integration/live.

## Key File References
Table mapping source files to their purpose in this architecture.
```

## Style Guidelines

- **Living documents**: Architecture docs describe the current state, not a proposal. Update them when the system changes.
- **Tradeoffs are first-class**: Every non-obvious decision gets a "Conscious Tradeoffs" entry explaining the reasoning and accepted costs.
- **Reference source files**: Always link to the actual configuration files that implement what the document describes.
- **Mark in-progress changes**: Use blockquotes (`> **Note:**`) to flag sections that reflect target state from in-progress work.
- **Explain WHY, not just WHAT**: The configuration files show what exists. Architecture docs explain why it exists and why alternatives were rejected.

## Naming Conventions

Pattern: `<system-or-concern>.md` (kebab-case)

| Good | Bad |
|------|-----|
| `backup-strategy.md` | `backups.md` |
| `network-segmentation.md` | `netpol.md` |
| `secret-management.md` | `secrets.md` |

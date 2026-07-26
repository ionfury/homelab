# Feedback Classification Reference

## Signal → Classification → Target

| Feedback Signal | Classification | Typical Target |
|-----------------|----------------|----------------|
| "That's wrong" / "Actually..." | Correction | Source of incorrect info |
| "You should also know..." | Clarification | Related existing section |
| "When doing X, always Y" | New Pattern | Module CLAUDE.md or skill |
| "Never do X" / "Don't X" | Anti-Pattern | Root CLAUDE.md |
| "The workflow should be..." | Workflow | Skill (new or existing) |
| "I prefer..." / "Always use..." | Preference | Appropriate CLAUDE.md |

## Target Location Decision Tree

```
Is this correcting existing documentation?
├─ YES → Find and update the source
└─ NO → Continue

Is this an enterprise principle or universal process?
├─ YES → Root CLAUDE.md (Core Principles, Anti-Patterns)
└─ NO → Continue

Is this specific to a subsystem?
├─ Infrastructure (terragrunt, modules) → infrastructure/CLAUDE.md
├─ Kubernetes Platform (helm, flux)     → kubernetes/platform/CLAUDE.md
├─ Kubernetes Clusters (bootstrap)      → kubernetes/clusters/CLAUDE.md
├─ Task Runner                          → .taskfiles/CLAUDE.md
└─ NO → Continue

Is this a procedural workflow with 5+ steps?
├─ YES → Skill (create or update)
└─ NO → Module CLAUDE.md (quick reference / pattern)
```

## Content Formatting

**CLAUDE.md additions**: tables for comparisons, bullets for lists, code blocks for examples, concise reference material. Use Mermaid for flows — never ASCII art (see root CLAUDE.md "Diagram Standards").

**Skill additions**: procedural step-by-step, error handling, examples with context, cross-references.

**Anti-pattern additions**:
```markdown
- **NEVER** do X because Y
- **NEVER** do Z without explicit human approval
```

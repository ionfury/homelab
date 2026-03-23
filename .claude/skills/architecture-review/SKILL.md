---
name: architecture-review
description: |
  Architecture evaluation criteria and technology standards for the homelab.
  Preloaded into the designer agent to ground design decisions in established
  patterns and principles.

  Use when: (1) Evaluating a proposed technology addition, (2) Reviewing architecture decisions,
  (3) Assessing stack fit for a new component, (4) Comparing implementation approaches.

  Triggers: "architecture review", "evaluate technology", "stack fit", "should we use",
  "technology comparison", "design review", "architecture decision"
user-invocable: false
---

# Architecture Evaluation Framework

## Current Technology Stack

Current technology stack: see [references/technology-decisions.md](references/technology-decisions.md)

## Evaluation Criteria

When evaluating any proposed technology addition or architecture change, score against these criteria:

### 1. Principle Alignment

Score each core principle (Strong/Weak/Neutral):
- **Enterprise at Home**: Does it reflect production-grade patterns?
- **Everything as Code**: Can it be fully represented in git?
- **Automation is Key**: Does it reduce or increase manual toil?
- **Learning First**: Does it teach valuable enterprise skills?
- **DRY and Code Reuse**: Does it leverage existing patterns or create duplication?

### 2. Stack Fit

- Does this overlap with existing tools? (e.g., adding Redis when Dragonfly exists)
- Does it integrate with the GitOps workflow? (Must be Flux-deployable)
- Does it work on bare-metal? (No cloud-only services)
- Does it support the multi-cluster model? (dev → integration → live)

### 3. Operational Cost

- How is it monitored? (Must integrate with kube-prometheus-stack)
- How is it backed up? (Must have a recovery story)
- How does it handle upgrades? (Must be declarative, ideally via Renovate)
- What's the failure blast radius? (Isolated > cluster-wide)

### 4. Complexity Budget

- Is the complexity justified by the learning value?
- Could a simpler existing tool solve the same problem?
- What's the maintenance burden over 12 months?

### 5. Alternative Analysis

- What existing stack components could solve this? (Always check first)
- What are the top 2-3 alternatives in the ecosystem?
- What do other production homelabs use? (kubesearch research)

### 6. Failure Modes

- What happens when this component is unavailable?
- How does it interact with network policies? (Default deny)
- What's the recovery procedure? (Must be documented in a runbook)
- Can it self-heal? (Strong preference for self-healing)

## Anti-Patterns to Challenge

| Anti-Pattern | Why It's Wrong | Correct Approach |
|-------------|---------------|------------------|
| "Just run a container" without monitoring | Invisible failures, no alerting | ServiceMonitor + PrometheusRule required |
| Adding a new tool when existing ones suffice | Stack bloat, maintenance burden | Evaluate existing stack first |
| Skipping observability "for now" | Technical debt that never gets paid | Monitoring is day-1, not day-2 |
| Cloud-only services | Vendor lock-in, can't run on bare-metal | Self-hosted alternatives preferred |
| Single-instance without HA story | Single point of failure | At minimum, document recovery procedure |

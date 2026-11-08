# Infrastructure is applied by a human, not by CI

Terragrunt/OpenTofu changes are validated in CI but applied from a workstation with explicit human approval; GitOps automation covers Kubernetes only. Automated apply is too risky for now and has no safe place to run: cloud runners holding infrastructure credentials are risky, and on-prem runners would need an A/B-style apply that costs more than it is worth at this scale.

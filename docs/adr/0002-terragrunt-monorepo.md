# Terragrunt units, stacks and modules live in this repository

Infrastructure modules, units and stacks live under `infrastructure/` in this repo instead of being consumed as versioned modules from the external `homelab-modules` repository. One repo keeps infrastructure and Kubernetes changes reviewable together, and units stay thin while configuration carries environment-specific logic.

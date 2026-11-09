# Disaster-recovery restore is a deliberate manual step

Velero restore resources are kept in git but are not reconciled by Flux, and disaster recovery applies them by hand. When they were reconciled, recreating the resources re-ran restores and brought back deleted state, so this is an accepted exception to the no-manual-steps principle.

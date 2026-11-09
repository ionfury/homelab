# Delivery is direct build-to-live OCI artifacts with no pre-production gate

Every merge to `main` builds a stable OCI artifact that the live cluster pulls directly, with canary-checker validating after deployment. The earlier release-candidate flow gated on an integration cluster was removed because that cluster sat broken for about two months without anyone noticing, so the gate gave false confidence rather than safety.

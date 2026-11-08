# Cluster applications live in self-contained apps/<app>/ folders

Each cluster application keeps its HelmRelease, HelmRepository, values and supporting config together in `apps/<app>/`, registered in a thin apps ResourceSet. Having everything for an app in one place is worth repeating the HelmRelease scaffold per app.

## Considered Options

- Keep the generated `charts/` plus `config/` split and only colocate values files.
- "Registry v2": per-app folders with HelmReleases generated from a template. Rejected in favour of explicit per-app HelmReleases.

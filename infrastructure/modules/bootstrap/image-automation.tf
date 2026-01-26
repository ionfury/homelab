# Image automation resources for OCI artifact-based promotion
# Only created when source_type = "oci"
/*
resource "kubernetes_manifest" "image_repository" {
  count      = var.source_type == "oci" ? 1 : 0
  depends_on = [helm_release.flux_instance]

  manifest = {
    apiVersion = "image.toolkit.fluxcd.io/v1beta2"
    kind       = "ImageRepository"
    metadata = {
      name      = "platform"
      namespace = "flux-system"
    }
    spec = {
      image    = var.oci_url
      interval = "1m"
      provider = "generic"
    }
  }
}

resource "kubernetes_manifest" "image_policy" {
  count      = var.source_type == "oci" ? 1 : 0
  depends_on = [kubernetes_manifest.image_repository]

  manifest = {
    apiVersion = "image.toolkit.fluxcd.io/v1beta2"
    kind       = "ImagePolicy"
    metadata = {
      name      = "platform"
      namespace = "flux-system"
    }
    spec = {
      imageRepositoryRef = { name = "platform" }
      filterTags = {
        pattern = "^${replace(var.oci_tag_pattern, "*", "(?P<sha>[a-f0-9]+)")}$"
        extract = "$sha"
      }
      policy = { alphabetical = { order = "desc" } }
    }
  }
}
*/

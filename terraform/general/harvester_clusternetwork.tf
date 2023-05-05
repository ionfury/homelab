resource "harvester_clusternetwork" "rancher" {
  name        = "rancher"
  description = "Network for rancher management cluster."
}

resource "harvester_clusternetwork" "kubernetes" {
  name = "kubernetes"
}

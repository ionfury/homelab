resource "harvester_clusternetwork" "harvester" {
  name        = "harvester"
  description = "Network for harvester management cluster."
}

resource "harvester_clusternetwork" "kubernetes" {
  name        = "kubernetes"
  description = "Network dedicated for kubernetes nodes."
}

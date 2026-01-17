data "healthchecksio_channel" "this" {
  kind = "discord"
}

resource "healthchecksio_check" "this" {
  name = "${var.cluster_name}-heartbeat"
  desc = "Alertmanager heartbeat from cluster: ${var.cluster_name}."

  timeout  = 60            # seconds (minimum allowed by provider v2.3.0+)
  grace    = 300           # seconds
  schedule = "*/2 * * * *" # every 2 minutes
  timezone = "UTC"

  tags = [
    var.cluster_name,
    "alertmanager",
    "heartbeat",
    "managed-by-terraform"
  ]

  channels = [
    data.healthchecksio_channel.this.id
  ]
}

resource "kubernetes_secret" "healthchecksio_pingurl" {
  metadata {
    name      = "heartbeat-ping-url"
    namespace = "kube-system"
    annotations = {
      "replicator.v1.mittwald.de/replication-allowed" : "true"
      "replicator.v1.mittwald.de/replication-allowed-namespaces" : var.healthchecksio_replication_allowed_namespaces
    }
  }

  data = {
    url = healthchecksio_check.this.ping_url
  }
}


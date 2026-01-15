data "aws_ssm_parameter" "discord_webhook_url" {
  name = var.discord.webhook_url_store
}

resource "kubernetes_secret" "discord_webhook_url" {
  metadata {
    name      = "discord-webhook-url"
    namespace = "kube-system"
    annotations = {
      "replicator.v1.mittwald.de/replication-allowed" : "true"
      "replicator.v1.mittwald.de/replication-allowed-namespaces" : var.discord_replication_allowed_namespaces
    }
  }

  data = {
    url = data.aws_ssm_parameter.discord_webhook_url.value
  }
}

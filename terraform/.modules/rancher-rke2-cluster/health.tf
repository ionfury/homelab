data "healthchecksio_channel" "discord" {
  kind = "discord"
}

resource "healthchecksio_check" "cluster_heartbeat" {
  name = "${var.name}-heartbeat"
  desc = "Alertmanager heartbeat from cluster: ${var.name}."

  timeout  = 120         # seconds
  grace    = 300         # seconds
  schedule = "* * * * *" # every minute

  channels = [
    data.healthchecksio_channel.discord.id
  ]
}

resource "aws_ssm_parameter" "heartbeat_url" {
  name        = "k8s-${var.name}-healtcheck"
  description = "Health check information for cluster: ${var.name}."
  type        = "SecureString"
  value       = jsonencode({ "url" = "${healthchecksio_check.cluster_heartbeat.ping_url}" })
}

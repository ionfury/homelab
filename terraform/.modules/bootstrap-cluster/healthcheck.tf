data "healthchecksio_channel" "discord" {
  kind = "discord"
}

resource "healthchecksio_check" "cluster_heartbeat" {
  name = "${var.cluster_name}-heartbeat"
  desc = "Alertmanager heartbeat from cluster: ${var.cluster_name}."

  timeout  = 0           # seconds
  grace    = 300         # seconds
  schedule = "* * * * *" # every minute
  timezone = "UTC"

  channels = [
    data.healthchecksio_channel.discord.id
  ]
}

resource "aws_ssm_parameter" "heartbeat_url" {
  name        = "k8s-${var.cluster_name}-healtcheck"
  description = "Health check information for cluster: ${var.cluster_name}."
  type        = "SecureString"
  value       = jsonencode({ "url" = "${healthchecksio_check.cluster_heartbeat.ping_url}" })
}

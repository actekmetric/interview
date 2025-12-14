output "workspace_id" {
  description = "AMP workspace ID"
  value       = aws_prometheus_workspace.main.id
}

output "workspace_endpoint" {
  description = "AMP workspace endpoint (for remote_write)"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
}

output "workspace_query_endpoint" {
  description = "AMP workspace query endpoint"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/query"
}

output "workspace_arn" {
  description = "AMP workspace ARN"
  value       = aws_prometheus_workspace.main.arn
}

output "prometheus_agent_role_arn" {
  description = "IAM role ARN for Prometheus Agent (IRSA)"
  value       = aws_iam_role.prometheus_agent.arn
}

output "prometheus_agent_role_name" {
  description = "IAM role name for Prometheus Agent"
  value       = aws_iam_role.prometheus_agent.name
}

output "alert_sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "alert_sns_topic_name" {
  description = "SNS topic name for alerts"
  value       = aws_sns_topic.alerts.name
}

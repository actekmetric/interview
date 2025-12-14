output "workspace_id" {
  description = "Grafana workspace ID"
  value       = aws_grafana_workspace.main.id
}

output "workspace_endpoint" {
  description = "Grafana workspace URL"
  value       = aws_grafana_workspace.main.endpoint
}

output "workspace_arn" {
  description = "Grafana workspace ARN"
  value       = aws_grafana_workspace.main.arn
}

output "grafana_role_arn" {
  description = "IAM role ARN for Grafana"
  value       = aws_iam_role.grafana.arn
}

output "grafana_role_name" {
  description = "IAM role name for Grafana"
  value       = aws_iam_role.grafana.name
}

output "api_key" {
  description = "Grafana API key for automation (sensitive)"
  value       = var.create_api_key ? aws_grafana_workspace_api_key.automation[0].key : null
  sensitive   = true
}

data "aws_region" "current" {}

locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "grafana"
    },
    var.tags
  )
}

# Amazon Managed Grafana Workspace
resource "aws_grafana_workspace" "main" {
  name                     = "tekmetric-${var.environment}"
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = var.authentication_providers
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  data_sources = ["PROMETHEUS"]

  # Notification channels
  notification_destinations = var.enable_sns_notifications ? ["SNS"] : []

  tags = merge(
    local.common_tags,
    {
      Name = "tekmetric-${var.environment}-grafana"
    }
  )
}

# IAM Role for Grafana
resource "aws_iam_role" "grafana" {
  name = "tekmetric-${var.environment}-grafana-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "grafana.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Grafana - Query AMP
resource "aws_iam_role_policy" "grafana_amp_query" {
  name = "amp-query"
  role = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:ListWorkspaces",
          "aps:DescribeWorkspace",
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata"
        ]
        Resource = var.amp_workspace_arn
      }
    ]
  })
}

# IAM Policy for Grafana - SNS Notifications
resource "aws_iam_role_policy" "grafana_sns" {
  count = var.enable_sns_notifications ? 1 : 0
  name  = "sns-publish"
  role  = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:ListTopics"
        ]
        Resource = "*"
      }
    ]
  })
}

# Grafana Workspace API Key (optional - for API-based automation if needed)
resource "aws_grafana_workspace_api_key" "automation" {
  count = var.create_api_key ? 1 : 0

  key_name        = "automation-key"
  key_role        = "ADMIN"
  seconds_to_live = 2592000 # 30 days
  workspace_id    = aws_grafana_workspace.main.id
}

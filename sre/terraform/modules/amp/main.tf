locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "amp"
    },
    var.tags
  )
}

# AWS Managed Prometheus Workspace
resource "aws_prometheus_workspace" "main" {
  alias = "tekmetric-${var.environment}"

  tags = merge(
    local.common_tags,
    {
      Name = "tekmetric-${var.environment}-amp"
    }
  )
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "tekmetric-${var.environment}-amp-alerts"

  tags = local.common_tags
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alert Manager Configuration
resource "aws_prometheus_alert_manager_definition" "main" {
  workspace_id = aws_prometheus_workspace.main.id

  definition = <<-EOT
alertmanager_config: |
  route:
    receiver: 'sns-receiver'
    group_by: ['alertname', 'cluster', 'service']
    group_wait: 10s
    group_interval: 5m
    repeat_interval: 3h

  receivers:
  - name: 'sns-receiver'
    sns_configs:
    - topic_arn: ${aws_sns_topic.alerts.arn}
      sigv4:
        region: ${data.aws_region.current.name}
      subject: 'Alert: {{ .GroupLabels.alertname }}'
      message: |
        {{ range .Alerts }}
        *Alert:* {{ .Labels.alertname }}
        *Severity:* {{ .Labels.severity }}
        *Summary:* {{ .Annotations.summary }}
        *Description:* {{ .Annotations.description }}
        {{ end }}
EOT
}

# Alert Rules
resource "aws_prometheus_rule_group_namespace" "alerts" {
  workspace_id = aws_prometheus_workspace.main.id
  name         = "backend-alerts"

  data = <<-EOT
groups:
  - name: backend-service
    interval: 30s
    rules:
      # Service Down Alert
      - alert: BackendServiceDown
        expr: up{job="backend-service"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Backend service is down"
          description: "Backend service in {{ $labels.namespace }} has been down for more than 5 minutes."

      # High Error Rate Alert
      - alert: HighErrorRate
        expr: |
          (
            sum(rate(http_server_requests_seconds_count{status=~"5..",namespace="backend-services"}[5m]))
            /
            sum(rate(http_server_requests_seconds_count{namespace="backend-services"}[5m]))
          ) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"

      # High Memory Usage Alert
      - alert: HighMemoryUsage
        expr: |
          (
            jvm_memory_used_bytes{area="heap",namespace="backend-services"}
            /
            jvm_memory_max_bytes{area="heap",namespace="backend-services"}
          ) > 0.80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High JVM heap usage"
          description: "JVM heap usage is {{ $value | humanizePercentage }} (threshold: 80%)"

      # High Response Time Alert
      - alert: HighResponseTime
        expr: |
          histogram_quantile(0.95,
            sum(rate(http_server_requests_seconds_bucket{namespace="backend-services"}[5m])) by (le)
          ) > 1.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High response time"
          description: "P95 latency is {{ $value }}s (threshold: 1s)"

      # Pod Crash Looping
      - alert: PodCrashLooping
        expr: |
          rate(kube_pod_container_status_restarts_total{namespace="backend-services"}[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod is crash looping"
          description: "Pod {{ $labels.pod }} is restarting frequently"

  - name: cluster-health
    interval: 30s
    rules:
      # Node Not Ready
      - alert: NodeNotReady
        expr: kube_node_status_condition{condition="Ready",status="true"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node not ready"
          description: "Node {{ $labels.node }} has been NotReady for more than 5 minutes"

      # High Node CPU
      - alert: HighNodeCPU
        expr: |
          (
            1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance)
          ) > 0.80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High node CPU usage"
          description: "Node {{ $labels.instance }} CPU usage is {{ $value | humanizePercentage }}"

      # High Node Memory
      - alert: HighNodeMemory
        expr: |
          (
            1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
          ) > 0.80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High node memory usage"
          description: "Node {{ $labels.instance }} memory usage is {{ $value | humanizePercentage }}"
EOT
}

# IAM Role for Prometheus Agent (IRSA)
resource "aws_iam_role" "prometheus_agent" {
  name = "tekmetric-${var.environment}-prometheus-agent-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.cluster_oidc_issuer}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.cluster_oidc_issuer}:sub" = "system:serviceaccount:observability:prometheus-agent"
            "${var.cluster_oidc_issuer}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Prometheus Agent - AMP Remote Write
resource "aws_iam_role_policy" "prometheus_agent_amp" {
  name = "amp-remote-write"
  role = aws_iam_role.prometheus_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Resource = aws_prometheus_workspace.main.arn
      }
    ]
  })
}

# IAM Policy for Prometheus Agent - SNS Publish (for Alert Manager)
resource "aws_iam_role_policy" "prometheus_agent_sns" {
  name = "sns-publish"
  role = aws_iam_role.prometheus_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Development Environment Account Configuration

locals {
  environment = "dev"
  account_id  = "596308305263"  # TODO: Replace with actual dev AWS account ID

  # Kubernetes version
  k8s_version = "1.34"

  # Environment-specific settings
  enable_deletion_protection     = false
  enable_termination_protection  = false
  backup_retention_days          = 7
  flow_logs_retention_days       = 7
  enable_kms_encryption          = false
  single_nat_gateway             = true  # Cost optimization for dev
  enable_cloudwatch_logging      = true  # Enable CloudWatch logging for pods
}

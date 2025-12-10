# Development Environment Account Configuration

locals {
  environment = "dev"
  account_id  = "096610237522"  # TODO: Replace with actual dev AWS account ID

  # Environment-specific settings
  enable_deletion_protection     = false
  enable_termination_protection  = false
  backup_retention_days          = 7
  flow_logs_retention_days       = 7
  enable_kms_encryption          = false
  single_nat_gateway             = true  # Cost optimization for dev
}

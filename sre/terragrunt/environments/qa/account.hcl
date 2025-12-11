# QA Environment Account Configuration

locals {
  environment = "qa"
  account_id  = "234567890123"  # TODO: Replace with actual QA AWS account ID

  # Kubernetes version
  k8s_version = "1.34"

  # Environment-specific settings
  enable_deletion_protection     = false
  enable_termination_protection  = false
  backup_retention_days          = 14
  flow_logs_retention_days       = 14
  enable_kms_encryption          = false
  single_nat_gateway             = true  # Cost optimization for QA
}

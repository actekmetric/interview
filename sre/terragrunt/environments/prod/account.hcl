# Production Environment Account Configuration

locals {
  environment = "prod"
  account_id  = "345678901234"  # TODO: Replace with actual prod AWS account ID

  # Kubernetes version
  k8s_version = "1.34"

  # Environment-specific settings
  enable_deletion_protection     = true
  enable_termination_protection  = true
  backup_retention_days          = 30
  flow_logs_retention_days       = 30
  enable_kms_encryption          = true
  single_nat_gateway             = false  # HA with NAT per AZ
}

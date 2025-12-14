# Production Environment - AWS Managed Prometheus Configuration

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../terraform/modules/amp"
}

# Dependency on EKS cluster (must exist before AMP)
dependency "eks_cluster" {
  config_path = "../../eks-cluster"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
}

inputs = {
  environment         = local.environment
  cluster_name        = "tekmetric-${local.environment}"
  cluster_oidc_issuer = dependency.eks_cluster.outputs.cluster_oidc_issuer

  # Alert email for production environment
  alert_email = "prod-alerts@example.com" # TODO: Update with actual email

  # Retention period for production (30 days)
  retention_period_days = 30

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Module      = "amp"
  }
}

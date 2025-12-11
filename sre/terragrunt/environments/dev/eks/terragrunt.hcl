# Development EKS Configuration

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/eks"
}

# Dependency on networking module
dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    vpc_id              = "vpc-mock"
    private_subnet_ids  = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
    public_subnet_ids   = ["subnet-mock-4", "subnet-mock-5", "subnet-mock-6"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
}

inputs = {
  environment  = local.environment
  cluster_name = "tekmetric-${local.environment}"

  # Cluster version
  cluster_version = "1.34"

  # Network configuration from networking module
  vpc_id             = dependency.networking.outputs.vpc_id
  private_subnet_ids = dependency.networking.outputs.private_subnet_ids
  public_subnet_ids  = dependency.networking.outputs.public_subnet_ids

  # Endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Node group configuration for dev (smaller, cost-optimized)
  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 10
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      labels = {
        role = "general"
      }
      taints = []
    }
  }

  # OIDC provider for IRSA
  enable_irsa = true

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
}

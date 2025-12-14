# Development EKS Cluster Configuration (cluster + node groups only, no addons)

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/eks"
}

# Dependency on networking module
dependency "networking" {
  config_path = "../networking"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
  account_id       = local.environment_vars.locals.account_id
  k8s_version      = local.environment_vars.locals.k8s_version
}

inputs = {
  environment  = local.environment
  cluster_name = "tekmetric-${local.environment}"
  github_actions_role_arn = "arn:aws:iam::${local.account_id}:role/GitHubActionsRole-${local.environment}"

  # Cluster version (from account.hcl)
  cluster_version = local.k8s_version

  # Network configuration from networking module
  vpc_id             = dependency.networking.outputs.vpc_id
  private_subnet_ids = dependency.networking.outputs.private_subnet_ids
  public_subnet_ids  = dependency.networking.outputs.public_subnet_ids

  # Endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Disable addons (will be managed by eks-addons module)
  enable_addons = false

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

  # Create IAM group for EKS admins
  # Users added to this group will automatically get full cluster access
  create_eks_admin_group = true
  eks_admin_group_name   = "eks-${local.environment}-admins"

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
}

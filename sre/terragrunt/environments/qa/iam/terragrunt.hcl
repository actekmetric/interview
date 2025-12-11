# Development IAM Configuration

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/iam"
}

# Dependency on EKS module for IRSA
dependency "eks_cluster" {
  config_path = "../eks-cluster"

  mock_outputs = {
    cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/MOCK"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
  mock_outputs_merge_strategy_with_state = "shallow"
  # Uses mocks during plan if no state exists, real outputs during apply
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
  account_id       = local.environment_vars.locals.account_id
}

inputs = {
  environment = local.environment
  account_id  = local.account_id

  # GitHub OIDC configuration
  github_org         = "actekmetric"
  github_repo        = "interview"
  enable_github_oidc = true

  # IRSA roles (pass OIDC URL from cluster)
  cluster_oidc_issuer_url = dependency.eks_cluster.outputs.cluster_oidc_issuer_url
  enable_irsa_roles       = true
}

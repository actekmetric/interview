# Development EKS Addons Configuration (addons only, with IRSA roles)

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/eks-addons"
}

# Dependency on EKS cluster (must exist before addons)
dependency "eks_cluster" {
  config_path = "../eks-cluster"

  mock_outputs = {
    cluster_name    = "tekmetric-qa"
    cluster_version = "1.34"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
  skip_outputs = true  # Skip during plan - cluster must be applied first
}

# Dependency on IAM module for IRSA roles
dependency "iam" {
  config_path = "../iam"

  mock_outputs = {
    ebs_csi_driver_role_arn = "arn:aws:iam::123456789012:role/mock-ebs-csi-driver"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "plan"]
  mock_outputs_merge_strategy_with_state = "shallow"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
}

inputs = {
  cluster_name    = "tekmetric-${local.environment}"
  cluster_version = dependency.eks_cluster.outputs.cluster_version

  # IRSA roles from IAM module
  ebs_csi_driver_role_arn = dependency.iam.outputs.ebs_csi_driver_role_arn
}

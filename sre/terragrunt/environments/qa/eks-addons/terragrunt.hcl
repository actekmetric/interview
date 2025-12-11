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
}

# Dependency on IAM module for IRSA roles
dependency "iam" {
  config_path = "../iam"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
}

inputs = {
  cluster_name    = "tekmetric-${local.environment}"
  cluster_version = "1.34"

  # IRSA roles from IAM module
  ebs_csi_driver_role_arn = dependency.iam.outputs.ebs_csi_driver_role_arn
}

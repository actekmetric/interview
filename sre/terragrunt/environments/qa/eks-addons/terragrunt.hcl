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

  # Skip outputs during destroy (when resources are already destroyed)
  skip_outputs = true
}

# Dependency on IAM module for IRSA roles
dependency "iam" {
  config_path = "../iam"

  # Skip outputs during destroy (when resources are already destroyed)
  skip_outputs = true
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
  k8s_version      = local.environment_vars.locals.k8s_version
}

inputs = {
  cluster_name    = "tekmetric-${local.environment}"
  cluster_version = local.k8s_version

  # IRSA roles from IAM module
  ebs_csi_driver_role_arn = dependency.iam.outputs.ebs_csi_driver_role_arn
}

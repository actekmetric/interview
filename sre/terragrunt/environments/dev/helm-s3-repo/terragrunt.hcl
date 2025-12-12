include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/sre/terraform/modules/helm-s3-repo"
}

dependency "iam" {
  config_path = "../iam"
  mock_outputs = {
    github_actions_role_name = "GitHubActionsRole-dev"
  }
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  account_id  = local.environment_vars.locals.account_id
  region      = local.region_vars.locals.region
}

inputs = {
  bucket_name                        = "tekmetric-helm-charts-${local.environment}"
  environment                        = local.environment
  github_actions_role_name           = dependency.iam.outputs.github_actions_role_name
  noncurrent_version_expiration_days = 90

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Component   = "HelmRepository"
    Region      = local.region
  }
}

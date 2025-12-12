include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_repo_root()}/sre/terraform/modules/ecr"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  account_id  = local.environment_vars.locals.account_id
  region      = local.region_vars.locals.region
}

inputs = {
  repository_names = [
    "backend",
    # "frontend",
    # "api-gateway",
  ]

  image_tag_mutability  = "IMMUTABLE"  # Production safety
  scan_on_push         = true
  max_image_count      = 20  # Keep more versions in prod
  untagged_expire_days = 1   # Clean up quickly

  github_actions_role_arns = [
    "arn:aws:iam::${local.account_id}:role/GitHubActionsRole-${local.environment}"
  ]

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Component   = "ECR"
    region      = local.region
  }
}

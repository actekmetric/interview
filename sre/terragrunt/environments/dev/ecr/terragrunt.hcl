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
  # List of ECR repositories to create
  # To add a new microservice, just add its name here
  repository_names = [
    "backend",        # Core backend service
    # "frontend",      # Uncomment when ready
    # "api-gateway",   # Uncomment when ready
  ]

  # Repository settings
  image_tag_mutability  = "MUTABLE"
  scan_on_push         = true
  max_image_count      = 10
  untagged_expire_days = 7

  # Allow GitHub Actions role to push/pull images
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

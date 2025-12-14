# Dev Environment - Amazon Managed Grafana Configuration

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../terraform/modules/grafana"
}

# Dependency on AMP (must exist before Grafana)
dependency "amp" {
  config_path = "../amp"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  environment      = local.environment_vars.locals.environment
}

inputs = {
  environment       = local.environment
  amp_workspace_arn = dependency.amp.outputs.workspace_arn

  # Use AWS SSO for authentication
  authentication_providers = ["AWS_SSO"]

  # Enable SNS notifications
  enable_sns_notifications = true

  # API key not needed for manual datasource configuration
  # create_api_key = false (default)

  tags = {
    Environment = local.environment
    ManagedBy   = "Terraform"
    Module      = "grafana"
  }
}

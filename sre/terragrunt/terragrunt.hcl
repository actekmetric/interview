# Root Terragrunt Configuration
# This file defines common settings for all environments

locals {
  # Parse environment from path
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  account_id  = local.environment_vars.locals.account_id
  region      = local.region_vars.locals.region
  k8s_version = local.environment_vars.locals.k8s_version

  # Global tags applied to all resources
  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Repository  = "interview"
    Project     = "tekmetric"
  }
}

# Configure Terragrunt to automatically store Terraform state in S3
remote_state {
  backend = "s3"

  config = {
    bucket         = "tekmetric-terraform-state-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "tekmetric-terraform-locks-${local.account_id}"

    # Use role assumption for state access
    role_arn = "arn:aws:iam::${local.account_id}:role/TerraformExecution"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = "${local.region}"

  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/TerraformExecution"
  }

  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}
EOF
}

# Configure Terragrunt to use common variables
inputs = merge(
  local.common_tags,
  {
    environment = local.environment
    account_id  = local.account_id
    region      = local.region
    k8s_version = local.k8s_version
  }
)

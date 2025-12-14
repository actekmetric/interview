# Development Networking Configuration

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../terraform/modules/networking"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment = local.environment_vars.locals.environment
  region      = local.region_vars.locals.region
  azs         = local.region_vars.locals.availability_zones
}

inputs = {
  environment = local.environment

  # VPC configuration
  vpc_cidr = "10.2.0.0/16"

  # Subnet configuration across 3 AZs
  private_subnet_cidrs = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  public_subnet_cidrs  = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
  availability_zones   = local.azs

  # NAT Gateway configuration (single for cost optimization)
  enable_nat_gateway = true
  single_nat_gateway = false

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # VPC Flow Logs
  enable_flow_logs             = true
  flow_logs_retention_days     = local.environment_vars.locals.flow_logs_retention_days

  # VPC Endpoints
  enable_vpc_endpoints = true

  # Tags
  vpc_tags = {
    Name = "tekmetric-${local.environment}-vpc"
  }
}

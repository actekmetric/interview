output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

output "state_bucket_region" {
  description = "Region of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "lock_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

output "terraform_execution_role_arn" {
  description = "ARN of the IAM role for Terraform execution"
  value       = aws_iam_role.terraform_execution.arn
}

output "terraform_execution_role_name" {
  description = "Name of the IAM role for Terraform execution"
  value       = aws_iam_role.terraform_execution.name
}

output "terraform_state_access_role_arn" {
  description = "ARN of the IAM role for state access"
  value       = aws_iam_role.terraform_state_access.arn
}

output "kms_key_id" {
  description = "ID of the KMS key for state encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.terraform_state[0].id : null
}

output "kms_key_arn" {
  description = "ARN of the KMS key for state encryption (if enabled)"
  value       = var.enable_kms_encryption ? aws_kms_key.terraform_state[0].arn : null
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider (if enabled)"
  value       = var.enable_github_oidc ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role (if enabled)"
  value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].arn : null
}

output "github_actions_role_name" {
  description = "Name of the GitHub Actions IAM role (if enabled)"
  value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].name : null
}

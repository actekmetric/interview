output "repository_urls" {
  description = "Map of repository names to URLs"
  value = {
    for name, repo in aws_ecr_repository.main : name => repo.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to ARNs"
  value = {
    for name, repo in aws_ecr_repository.main : name => repo.arn
  }
}

output "registry_id" {
  description = "Registry ID (AWS Account ID)"
  value       = data.aws_caller_identity.current.account_id
}

output "registry_url" {
  description = "ECR registry URL"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.tags.region != null ? var.tags.region : "us-east-1"}.amazonaws.com"
}

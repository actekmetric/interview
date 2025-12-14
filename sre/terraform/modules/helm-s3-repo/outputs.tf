# Helm S3 Repository Module Outputs

output "bucket_name" {
  description = "S3 bucket name for Helm charts"
  value       = aws_s3_bucket.helm_charts.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.helm_charts.arn
}

output "helm_repo_uri" {
  description = "Helm repository URI for s3 plugin (s3://bucket/charts)"
  value       = "s3://${aws_s3_bucket.helm_charts.id}/charts"
}

output "helm_s3_policy_arn" {
  description = "IAM policy ARN for Helm S3 access"
  value       = aws_iam_policy.helm_s3_access.arn
}

# Helm S3 Repository Module Variables

variable "bucket_name" {
  description = "S3 bucket name for Helm charts"
  type        = string
}

variable "environment" {
  description = "Environment name (dev/qa/prod)"
  type        = string
}

variable "github_actions_role_name" {
  description = "IAM role name used by GitHub Actions"
  type        = string
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep noncurrent versions of chart packages"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_prefix" {
  description = "Prefix for the state bucket name"
  type        = string
  default     = "tekmetric-terraform-state"
}

variable "lock_table_prefix" {
  description = "Prefix for the lock table name"
  type        = string
  default     = "tekmetric-terraform-locks"
}

variable "enable_versioning" {
  description = "Enable versioning for the state bucket"
  type        = bool
  default     = true
}

variable "versioning_lifecycle_days" {
  description = "Number of days to keep old versions"
  type        = number
  default     = 30
}

variable "enable_kms_encryption" {
  description = "Use KMS encryption instead of AES-256"
  type        = bool
  default     = false
}

variable "enable_mfa_delete" {
  description = "Enable MFA delete for production environments"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

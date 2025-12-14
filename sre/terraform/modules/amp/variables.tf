variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_oidc_issuer" {
  description = "EKS cluster OIDC issuer URL (without https://)"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}

variable "retention_period_days" {
  description = "Metrics retention period in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

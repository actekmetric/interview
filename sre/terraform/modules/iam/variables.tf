variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "actekmetric"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "interview"
}

variable "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster (for IRSA roles)"
  type        = string
  default     = ""
}

variable "enable_github_oidc" {
  description = "Create GitHub OIDC provider and roles"
  type        = bool
  default     = true
}

variable "enable_irsa_roles" {
  description = "Create IRSA roles for EKS add-ons"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

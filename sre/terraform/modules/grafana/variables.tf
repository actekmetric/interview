variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "amp_workspace_arn" {
  description = "ARN of the AMP workspace to query"
  type        = string
}

variable "authentication_providers" {
  description = "Authentication providers for Grafana (AWS_SSO, SAML)"
  type        = list(string)
  default     = ["AWS_SSO"]
}

variable "enable_sns_notifications" {
  description = "Enable SNS notifications in Grafana"
  type        = bool
  default     = true
}

variable "create_api_key" {
  description = "Create API key for automation (optional - only needed for API-based integrations)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

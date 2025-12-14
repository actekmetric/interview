variable "environment" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancers"
  type        = list(string)
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_enabled_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    labels         = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {}
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver (IRSA)"
  type        = string
  default     = ""
}

variable "enable_addons" {
  description = "Enable EKS addons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_observability" {
  description = "Enable CloudWatch Observability add-on for logging (Fluent Bit)"
  type        = bool
  default     = true
}

variable "create_eks_admin_group" {
  description = "Create an IAM group for EKS cluster admins"
  type        = bool
  default     = false
}

variable "eks_admin_group_name" {
  description = "Name of the IAM group for EKS cluster admins"
  type        = string
  default     = "eks-cluster-admins"
}

variable "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role for CI/CD deployments"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version of the cluster"
  type        = string
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver (IRSA)"
  type        = string
}

variable "aws_load_balancer_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller (IRSA)"
  type        = string
  default     = ""
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler (IRSA)"
  type        = string
  default     = ""
}

variable "enable_cloudwatch_observability" {
  description = "Enable CloudWatch Observability add-on for logging (Fluent Bit)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

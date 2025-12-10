output "github_oidc_provider_arn" {
  description = "ARN of GitHub OIDC provider"
  value       = var.enable_github_oidc ? aws_iam_openid_connect_provider.github[0].arn : null
}

output "github_actions_role_arn" {
  description = "ARN of GitHub Actions IAM role"
  value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].arn : null
}

output "github_actions_role_name" {
  description = "Name of GitHub Actions IAM role"
  value       = var.enable_github_oidc ? aws_iam_role.github_actions[0].name : null
}

output "terraform_execution_policy_arn" {
  description = "ARN of Terraform execution policy"
  value       = var.enable_github_oidc ? aws_iam_policy.terraform_execution[0].arn : null
}

output "eks_deployment_policy_arn" {
  description = "ARN of EKS deployment policy"
  value       = var.enable_github_oidc ? aws_iam_policy.eks_deployment[0].arn : null
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of AWS Load Balancer Controller IRSA role"
  value       = var.enable_irsa_roles && var.cluster_oidc_issuer_url != "" ? aws_iam_role.aws_load_balancer_controller[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of EBS CSI Driver IRSA role"
  value       = var.enable_irsa_roles && var.cluster_oidc_issuer_url != "" ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of Cluster Autoscaler IRSA role"
  value       = var.enable_irsa_roles && var.cluster_oidc_issuer_url != "" ? aws_iam_role.cluster_autoscaler[0].arn : null
}

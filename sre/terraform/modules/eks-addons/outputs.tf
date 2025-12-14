output "vpc_cni_addon_id" {
  description = "ID of VPC CNI addon"
  value       = aws_eks_addon.vpc_cni.id
}

output "coredns_addon_id" {
  description = "ID of CoreDNS addon"
  value       = aws_eks_addon.coredns.id
}

output "kube_proxy_addon_id" {
  description = "ID of kube-proxy addon"
  value       = aws_eks_addon.kube_proxy.id
}

output "ebs_csi_driver_addon_id" {
  description = "ID of EBS CSI driver addon (null if not installed)"
  value       = length(aws_eks_addon.ebs_csi_driver) > 0 ? aws_eks_addon.ebs_csi_driver[0].id : null
}

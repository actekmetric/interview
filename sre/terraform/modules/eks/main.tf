locals {
  common_tags = merge(
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Module      = "eks"
    },
    var.tags
  )
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.environment == "prod" ? 30 : 7

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-logs"
    }
  )
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_vpc_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids = concat(var.private_subnet_ids, var.public_subnet_ids)

    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
  }

  # Enable API authentication mode to support Access Entries
  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.cluster_vpc_policy,
    aws_cloudwatch_log_group.cluster
  ]

  tags = merge(
    local.common_tags,
    {
      Name = var.cluster_name
    }
  )
}

# OIDC Provider for IRSA
data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-oidc"
    }
  )
}

# IAM Role for Node Groups
resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_group_registry_policy" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Managed Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-${each.key}"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = merge(
    each.value.labels,
    {
      Environment = var.environment
      NodeGroup   = each.key
    }
  )

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_registry_policy
  ]

  tags = merge(
    local.common_tags,
    {
      Name                                            = "${var.cluster_name}-${each.key}"
      "k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
      "k8s.io/cluster-autoscaler/enabled"             = "true"
    }
  )
}

# EKS Add-ons (optional, can be managed separately)
resource "aws_eks_addon" "vpc_cni" {
  count = var.enable_addons ? 1 : 0

  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"

  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = local.common_tags
}

resource "aws_eks_addon" "coredns" {
  count = var.enable_addons ? 1 : 0

  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"

  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = local.common_tags
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.enable_addons ? 1 : 0

  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"

  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = local.common_tags
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.enable_addons ? 1 : 0

  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"

  addon_version               = data.aws_eks_addon_version.ebs_csi_driver.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = var.ebs_csi_driver_role_arn != "" ? var.ebs_csi_driver_role_arn : null

  timeouts {
    create = "30m"
    update = "30m"
    delete = "15m"
  }

  depends_on = [
    aws_eks_node_group.main
  ]

  tags = local.common_tags
}

# Data sources for latest addon versions
data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

# IAM Role for EKS cluster admins (users in the group can assume this role)
resource "aws_iam_role" "eks_admins" {
  count = var.create_eks_admin_group ? 1 : 0
  name  = "${var.cluster_name}-admins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
      # Allow both IAM Users and AssumedRoles (for switch role access)
      Condition = {
        StringLike = {
          "aws:PrincipalType" = ["User", "AssumedRole"]
        }
      }
    }]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "${var.cluster_name}-admins-role"
    }
  )
}

# IAM Group for EKS cluster admins
resource "aws_iam_group" "eks_admins" {
  count = var.create_eks_admin_group ? 1 : 0
  name  = var.eks_admin_group_name
  path  = "/"
}

# Policy to allow group members to assume the EKS admin role
resource "aws_iam_group_policy" "assume_eks_admin_role" {
  count = var.create_eks_admin_group ? 1 : 0
  name  = "AssumeEKSAdminRole"
  group = aws_iam_group.eks_admins[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.eks_admins[0].arn
    }]
  })
}

# EKS Access Entry for the IAM role
resource "aws_eks_access_entry" "role_admin" {
  count = var.create_eks_admin_group ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_admins[0].arn
  type          = "STANDARD"

  tags = merge(
    local.common_tags,
    {
      Name = "eks-admin-role"
    }
  )
}

# Associate cluster admin policy with the role
resource "aws_eks_access_policy_association" "role_admin" {
  count = var.create_eks_admin_group ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_admins[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.role_admin]
}

# EKS Access Entry for GitHub Actions CI/CD
resource "aws_eks_access_entry" "github_actions" {
  count = var.github_actions_role_arn != "" ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.github_actions_role_arn
  type          = "STANDARD"

  tags = merge(
    local.common_tags,
    {
      Name = "github-actions-cicd"
    }
  )
}

# Associate cluster admin policy with GitHub Actions role (for deployments)
resource "aws_eks_access_policy_association" "github_actions" {
  count = var.github_actions_role_arn != "" ? 1 : 0

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = var.github_actions_role_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_actions]
}

# Data source for current account
data "aws_caller_identity" "current" {}

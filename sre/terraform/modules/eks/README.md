# EKS Terraform Module

This module provisions an Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups.

## Features

- EKS cluster with configurable Kubernetes version
- Managed node groups with auto-scaling
- Optional EKS add-ons (VPC CNI, CoreDNS, kube-proxy, EBS CSI driver)
- IRSA (IAM Roles for Service Accounts) support
- CloudWatch logging for cluster audit logs
- IAM group-based access management for cluster admins

## IAM Group-Based Access Management

The module can create an IAM group and role that grant full cluster admin access to group members.

### How It Works

1. **Terraform creates an IAM role** (e.g., `tekmetric-dev-admins-role`) with EKS cluster admin access
2. **Terraform creates an IAM group** (e.g., `eks-dev-admins`) that can assume the role
3. **You add/remove users manually** to the group via AWS Console or CLI
4. **Users in the group assume the role to access EKS** - no Terraform changes needed

### Configuration

```hcl
create_eks_admin_group = true
eks_admin_group_name   = "eks-dev-admins"
```

### Adding Users to the Group

After applying the Terraform configuration, add users to the group:

```bash
# Add a user to the EKS admin group
aws iam add-user-to-group \
  --user-name automation-dev \
  --group-name eks-dev-admins

# Add another user
aws iam add-user-to-group \
  --user-name jane-doe \
  --group-name eks-dev-admins
```

### Accessing the Cluster

Once a user is added to the group, they can access the cluster by assuming the role:

```bash
# Option 1: Update kubeconfig with role assumption (recommended)
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1 \
  --role-arn arn:aws:iam::096610237522:role/tekmetric-dev-admins-role

# Option 2: Assume role first, then update kubeconfig
aws sts assume-role \
  --role-arn arn:aws:iam::096610237522:role/tekmetric-dev-admins-role \
  --role-session-name eks-admin-session

# Export the temporary credentials (from assume-role output)
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."

# Update kubeconfig
aws eks update-kubeconfig --name tekmetric-dev --region us-east-1

# Verify access
kubectl get nodes
kubectl get pods -A
```

### Removing Users

```bash
# Remove a user from the group
aws iam remove-user-from-group \
  --user-name automation-dev \
  --group-name eks-dev-admins
```

The user will immediately lose cluster access.

## Usage Example

```hcl
module "eks" {
  source = "../../../../terraform/modules/eks"

  environment     = "dev"
  cluster_name    = "tekmetric-dev"
  cluster_version = "1.34"

  # Networking
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids

  # Node groups
  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 10
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      labels = {
        role = "general"
      }
      taints = []
    }
  }

  # IAM group for EKS admins
  create_eks_admin_group = true
  eks_admin_group_name   = "eks-dev-admins"

  # IRSA
  enable_irsa = true

  # Add-ons
  enable_addons = false  # Managed separately by eks-addons module

  # Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| environment | Environment name | string | n/a | yes |
| cluster_name | Name of the EKS cluster | string | n/a | yes |
| cluster_version | Kubernetes version | string | n/a | yes |
| vpc_id | VPC ID where cluster will be created | string | n/a | yes |
| private_subnet_ids | List of private subnet IDs for nodes | list(string) | n/a | yes |
| public_subnet_ids | List of public subnet IDs for control plane | list(string) | n/a | yes |
| node_groups | Map of node group configurations | map(object) | {} | no |
| cluster_endpoint_public_access | Enable public API server endpoint | bool | true | no |
| cluster_endpoint_private_access | Enable private API server endpoint | bool | true | no |
| enable_irsa | Enable IRSA (IAM Roles for Service Accounts) | bool | false | no |
| enable_addons | Enable EKS addons | bool | true | no |
| create_eks_admin_group | Create an IAM group for EKS cluster admins | bool | false | no |
| eks_admin_group_name | Name of the IAM group for EKS cluster admins | string | "eks-cluster-admins" | no |
| cluster_enabled_log_types | List of control plane logging types | list(string) | [] | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | EKS cluster ID |
| cluster_name | EKS cluster name |
| cluster_arn | EKS cluster ARN |
| cluster_endpoint | EKS cluster API endpoint |
| cluster_certificate_authority_data | Base64 encoded certificate data |
| cluster_version | EKS cluster Kubernetes version |
| cluster_oidc_issuer_url | OIDC issuer URL for IRSA |
| cluster_security_group_id | Security group ID attached to the cluster |
| cluster_iam_role_arn | IAM role ARN of the EKS cluster |
| node_group_iam_role_arn | IAM role ARN of the node groups |
| node_groups | Map of node group attributes |
| cloudwatch_log_group_name | CloudWatch log group name for cluster logs |
| eks_admin_group_name | Name of the IAM group for EKS cluster admins |
| eks_admin_group_arn | ARN of the IAM group for EKS cluster admins |

## Notes

- **Access Management**: The module uses the modern EKS Access Entries API instead of the deprecated aws-auth ConfigMap
- **Role + Group Pattern**: Users join a group → group can assume a role → role has EKS access
- **Why Not Direct Group Access**: EKS Access Entries API only supports IAM users and roles, not groups
- **No Terraform Updates**: Adding/removing users doesn't require Terraform changes - just IAM group membership updates
- **Instant Access**: Changes to group membership take effect immediately (users must assume role)
- **Multiple Environments**: Each environment can have its own admin group and role

## Security Considerations

- Users in the admin group have **full cluster access** (cluster-admin equivalent)
- Consider creating additional groups with more restrictive policies for non-admin users
- Regularly audit group membership
- Use AWS CloudTrail to track group membership changes
- Follow the principle of least privilege when adding users

# IAM Module

This module manages IAM roles and policies for GitHub Actions and EKS IRSA (IAM Roles for Service Accounts).

## Purpose

Creates:
- GitHub OIDC provider for secure CI/CD authentication
- GitHub Actions IAM role for Terraform and EKS deployments
- IRSA roles for EKS add-ons (Load Balancer Controller, EBS CSI, Cluster Autoscaler)

## Resources Created

### GitHub OIDC
- **OIDC Provider**: token.actions.githubusercontent.com
- **GitHub Actions Role**: Assumed via OIDC for CI/CD operations
- **Terraform Execution Policy**: Full access to provision infrastructure
- **EKS Deployment Policy**: Access to EKS clusters and ECR

### IRSA Roles (EKS Add-ons)
- **AWS Load Balancer Controller**: Manages ALB/NLB for Ingress
- **EBS CSI Driver**: Manages EBS volumes for PersistentVolumes
- **Cluster Autoscaler**: Auto-scales EKS node groups

## Usage

### Basic Configuration (GitHub OIDC Only)
```hcl
module "iam" {
  source = "../../../terraform/modules/iam"

  environment        = "dev"
  account_id         = "123456789012"
  github_org         = "actekmetric"
  github_repo        = "interview"
  enable_github_oidc = true
  enable_irsa_roles  = false  # Enable after EKS cluster exists
}
```

### With IRSA Roles
```hcl
module "iam" {
  source = "../../../terraform/modules/iam"

  environment             = "dev"
  account_id              = "123456789012"
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  enable_github_oidc      = true
  enable_irsa_roles       = true
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| account_id | AWS Account ID | string | - | yes |
| github_org | GitHub organization | string | actekmetric | no |
| github_repo | GitHub repository | string | interview | no |
| cluster_oidc_issuer_url | EKS OIDC issuer URL | string | "" | no |
| enable_github_oidc | Create GitHub OIDC | bool | true | no |
| enable_irsa_roles | Create IRSA roles | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| github_oidc_provider_arn | GitHub OIDC provider ARN |
| github_actions_role_arn | GitHub Actions role ARN |
| terraform_execution_policy_arn | Terraform policy ARN |
| eks_deployment_policy_arn | EKS deployment policy ARN |
| aws_load_balancer_controller_role_arn | ALB controller role ARN |
| ebs_csi_driver_role_arn | EBS CSI role ARN |
| cluster_autoscaler_role_arn | Cluster autoscaler role ARN |

## GitHub Actions Configuration

After creating the IAM module, configure GitHub secrets:

```bash
# Get role ARN
terraform output github_actions_role_arn

# Add to GitHub secrets as:
AWS_DEV_ROLE_ARN=arn:aws:iam::123456789012:role/GitHubActionsRole-dev
AWS_DEV_ACCOUNT_ID=123456789012
```

## GitHub Workflow Example

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write  # Required for OIDC
      contents: read

    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEV_ROLE_ARN }}
          aws-region: us-east-1

      - name: Verify access
        run: aws sts get-caller-identity
```

## Security Considerations

### GitHub OIDC Benefits
- **No long-lived credentials**: Short-lived tokens (1 hour)
- **Repository scoped**: Only specified repos can assume role
- **Auditable**: CloudTrail logs all assumptions
- **Revocable**: Delete OIDC provider to revoke all access

### IRSA Benefits
- **Pod-level permissions**: Each pod gets specific IAM role
- **No node credentials**: Credentials injected via webhook
- **Automatic rotation**: Tokens expire and refresh automatically
- **Least privilege**: Each service gets only required permissions

## Troubleshooting

### OIDC Authentication Failures
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check role trust policy
aws iam get-role --role-name GitHubActionsRole-dev

# Verify thumbprint
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com
```

### IRSA Issues
```bash
# Check if service account has annotation
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml

# Verify OIDC provider
aws eks describe-cluster --name tekmetric-dev \
  --query "cluster.identity.oidc.issuer" --output text

# Test from pod
kubectl run -it --rm debug --image=amazon/aws-cli --restart=Never \
  -- sts get-caller-identity
```

## Cost

- **IAM Roles**: Free
- **OIDC Provider**: Free
- **API Calls**: Minimal cost
- **Total**: $0/month

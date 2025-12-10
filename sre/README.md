# SRE Infrastructure - GitOps with Terragrunt + Terraform

Complete GitOps infrastructure for multi-account AWS environments (dev, qa, prod) with EKS clusters and automated lifecycle management.

## 🏗️ Architecture

- **Infrastructure as Code**: Terragrunt + Terraform
- **Container Orchestration**: Amazon EKS (Kubernetes 1.28)
- **Networking**: Custom VPC with public/private subnets across 3 AZs
- **Authentication**: GitHub OIDC (no long-lived credentials)
- **GitOps**: GitHub Actions workflows

## 📂 Directory Structure

```
sre/
├── terraform/          # Terraform modules
│   ├── modules/
│   │   ├── bootstrap/  # S3 state backend, DynamoDB locks
│   │   ├── networking/ # VPC, subnets, NAT, security groups
│   │   ├── eks/        # EKS cluster, node groups, add-ons
│   │   └── iam/        # GitHub OIDC, IAM roles for IRSA
│   └── policies/       # Reusable IAM policy documents
├── terragrunt/         # Terragrunt configurations
│   ├── terragrunt.hcl  # Root configuration
│   └── environments/   # Environment-specific configs
│       ├── dev/
│       ├── qa/
│       └── prod/
├── scripts/            # Helper scripts
│   └── scale-workloads.sh  # Start/stop environments
├── k8s/                # Kubernetes manifests
│   ├── workload-state/ # Replica count state per environment
│   └── base/           # Base K8s resources
└── helm/               # Existing Helm charts
    ├── backend/
    └── common/
```

## 🚀 Quick Start

### Prerequisites

1. **AWS Accounts**: Separate accounts for dev, qa, prod
2. **GitHub Secrets**: Configure OIDC credentials (see below)
3. **Tools** (for local dev):
   - Terraform >= 1.6.0
   - Terragrunt >= 0.54.0
   - kubectl >= 1.28
   - AWS CLI

### Step 1: Bootstrap AWS Accounts

**Important**: Bootstrap must be done once per account manually before using Terragrunt.

```bash
cd sre/terraform/modules/bootstrap
terraform init
terraform apply \
  -var="environment=dev" \
  -var="account_id=096610237522" \
  -var="region=us-east-1"
```

This creates:
- S3 bucket: `tekmetric-terraform-state-{account-id}`
- DynamoDB table: `tekmetric-terraform-locks-{account-id}`
- IAM roles: `TerraformExecution`, `TerraformStateAccess`

Repeat for QA and Prod accounts.

### Step 2: Configure GitHub Secrets

In GitHub repository settings, add these secrets:

```
AWS_DEV_ACCOUNT_ID=123456789012
AWS_DEV_ROLE_ARN=arn:aws:iam::123456789012:role/GitHubActionsRole-dev

AWS_QA_ACCOUNT_ID=234567890123
AWS_QA_ROLE_ARN=arn:aws:iam::234567890123:role/GitHubActionsRole-qa

AWS_PROD_ACCOUNT_ID=345678901234
AWS_PROD_ROLE_ARN=arn:aws:iam::345678901234:role/GitHubActionsRole-prod
```

### Step 3: Update Account IDs

Edit these files with actual AWS account IDs:
- `sre/terragrunt/environments/dev/account.hcl`
- `sre/terragrunt/environments/qa/account.hcl`
- `sre/terragrunt/environments/prod/account.hcl`

### Step 4: Deploy Infrastructure

**Option A: Via GitHub Actions (Recommended)**

1. Create a PR with infrastructure changes
2. Workflow `sre-terraform-plan` runs automatically
3. Review plan output in PR
4. Merge PR to trigger `sre-terraform-apply`

**Option B: Locally**

```bash
cd sre/terragrunt/environments/dev

# Plan
terragrunt run-all plan

# Apply
terragrunt run-all apply
```

## 🛠️ GitHub Workflows

### Infrastructure Management

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **terraform-plan** | PR to master | Preview infrastructure changes |
| **terraform-apply** | Push to master | Deploy infrastructure changes |

### Environment Lifecycle

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **environment-start** | Manual | Scale workloads from 0 to saved replica counts |
| **environment-stop** | Manual | Scale workloads to 0 (keeps infrastructure) |
| **environment-destroy** | Manual | Destroy all infrastructure (non-prod only) |

### Usage Examples

**Stop environment for cost savings (nights/weekends)**:
```
Actions → Start Environment → Select environment → Run workflow
```
Saves ~70% on compute costs, infrastructure remains available.

**Start environment**:
```
Actions → Stop Environment → Select environment → Run workflow
```
Restarts in minutes from saved state.

**Destroy environment completely**:
```
Actions → Destroy Environment → Select dev/qa → Type "destroy" → Run workflow
```
Complete teardown, 100% cost savings.

## 📊 Cost Estimates

### Per Environment (Monthly)

**Development/QA**:
- EKS control plane: $72
- NAT Gateway: $32
- EC2 nodes (2x t3.medium): ~$60
- **Total**: ~$180/month

**Production**:
- EKS control plane: $72
- NAT Gateways (3x): $96
- EC2 nodes (5x t3.large): ~$300
- **Total**: ~$520/month

**Annual Total**: ~$12,000/year (all environments)

**Cost Optimization**:
- Scale to zero (nights/weekends): 50% savings on compute
- Destroy non-prod (when unused): 70% savings
- Spot instances: 60-70% savings (dev/qa)

## 🔐 Security Features

- **GitHub OIDC**: No long-lived AWS credentials
- **Multi-account isolation**: Separate AWS accounts per environment
- **IRSA**: Pod-level IAM permissions
- **VPC endpoints**: Keep traffic within AWS
- **Encrypted state**: S3 + DynamoDB with encryption
- **Audit logging**: CloudTrail + VPC Flow Logs

## 📖 Module Documentation

Detailed documentation for each module:

- [Bootstrap Module](terraform/modules/bootstrap/README.md) - S3 state backend setup
- [Networking Module](terraform/modules/networking/README.md) - VPC and networking
- [IAM Module](terraform/modules/iam/README.md) - GitHub OIDC and IRSA roles
- [EKS Module](terraform/modules/eks/README.md) - Kubernetes clusters

## 🔧 Common Operations

### Get EKS Credentials

```bash
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1 \
  --role-arn arn:aws:iam::123456789012:role/GitHubActionsRole-dev
```

### Scale Workloads Manually

```bash
# Stop (save state and scale to zero)
./sre/scripts/scale-workloads.sh dev save

# Start (restore from saved state)
./sre/scripts/scale-workloads.sh dev restore
```

### Deploy New Helm Chart Version

The existing `service-backend-workflow.yml` automatically deploys to EKS after publishing charts.

### Terraform Plan for Specific Module

```bash
cd sre/terragrunt/environments/dev/eks
terragrunt plan
```

### Destroy Specific Module

```bash
cd sre/terragrunt/environments/dev/eks
terragrunt destroy
```

## 🚨 Troubleshooting

### OIDC Authentication Fails

```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Check role trust policy
aws iam get-role --role-name GitHubActionsRole-dev
```

### Terragrunt State Lock

```bash
# List locks
aws dynamodb scan --table-name tekmetric-terraform-locks-123456789012

# Delete stale lock (use with caution)
aws dynamodb delete-item \
  --table-name tekmetric-terraform-locks-123456789012 \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

### EKS Connection Issues

```bash
# Verify cluster exists
aws eks describe-cluster --name tekmetric-dev

# Check node status
kubectl get nodes

# Check pod status
kubectl get pods -A
```

## 📋 Implementation Checklist

- [ ] Bootstrap all AWS accounts (dev, qa, prod)
- [ ] Configure GitHub OIDC in each account
- [ ] Update account IDs in terragrunt configs
- [ ] Add GitHub secrets
- [ ] Deploy dev environment
- [ ] Test start/stop workflows
- [ ] Deploy qa environment
- [ ] Deploy prod environment
- [ ] Configure monitoring and alerts
- [ ] Document runbooks for team

## 🤝 Contributing

1. Create feature branch
2. Make changes
3. Run `terraform fmt` and `terraform validate`
4. Create PR (terraform-plan workflow runs automatically)
5. Review plan output
6. Merge to deploy

## 📚 Additional Resources

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Helm Chart Repository](../helm/README.md)

## 📞 Support

For issues or questions:
- Infrastructure: Create issue with label `infrastructure`
- Security: Contact security team
- Runbooks: See `/docs/runbooks/` (to be created)

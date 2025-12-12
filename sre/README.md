# SRE Infrastructure - GitOps with Terragrunt + Terraform

Complete GitOps infrastructure for multi-account AWS environments (dev, qa, prod) with EKS clusters and automated lifecycle management.

## 🌟 Key Features

- **AWS Multi-Account Setup** - Separate accounts for dev, qa, prod
- **Amazon EKS** - Kubernetes 1.34 with managed node groups
- **Infrastructure as Code** - Terraform + Terragrunt with staged deployments
- **GitHub Actions CI/CD** - Automated workflows for infrastructure and applications
- **Security** - GitHub OIDC authentication, IRSA for pod-level permissions
- **Cost Optimization** - Environment start/stop workflows for dev/qa

## 🔗 Quick Navigation

- **[Complete Setup Guide](SETUP-GUIDE.md)** - Step-by-step setup from scratch (START HERE!)
- [Staged Deployment Guide](STAGED-DEPLOYMENT.md) - Infrastructure deployment strategy
- [Kubernetes Version Management](terragrunt/K8S-UPGRADE.md) - How to upgrade K8s versions
- [GitHub Workflows Documentation](../.github/workflows/README.md) - CI/CD workflows
- [Custom Actions Documentation](../.github/actions/README.md) - Reusable GitHub Actions

## 🛠️ Technologies

- **Infrastructure**: Terraform, Terragrunt, AWS (EKS, VPC, IAM, S3, DynamoDB)
- **CI/CD**: GitHub Actions, GitHub OIDC
- **Containers**: Docker, Kubernetes, Helm
- **Security**: Trivy scanning, IRSA, encrypted state
- **Observability**: CloudWatch, VPC Flow Logs

## 🏗️ Architecture

- **Infrastructure as Code**: Terragrunt + Terraform
- **Container Orchestration**: Amazon EKS (Kubernetes 1.34)
- **Networking**: Custom VPC with public/private subnets across 3 AZs
- **Authentication**: GitHub OIDC (no long-lived credentials)
- **GitOps**: GitHub Actions workflows
- **Deployment Strategy**: Staged deployments (4 sequential stages)

### Module Architecture

The infrastructure is split into 4 deployment stages to eliminate circular dependencies:

1. **Networking** - Creates VPC, subnets, NAT gateways, security groups
2. **EKS Cluster** - Creates EKS control plane and node groups (no addons)
3. **IAM** - Creates IRSA roles for service accounts (requires EKS OIDC URL)
4. **EKS Addons** - Installs EKS addons with IRSA roles (EBS CSI driver, CoreDNS, etc.)

This separation ensures:
- ✅ No circular dependencies between EKS and IAM modules
- ✅ IRSA roles can be created after cluster exists
- ✅ Addons can use IRSA roles for secure AWS API access
- ✅ Clean deployment order: networking → cluster → iam → addons

## 📂 Directory Structure

```
sre/
├── terraform/              # Terraform modules
│   ├── modules/
│   │   ├── bootstrap/      # S3 state backend, DynamoDB locks, GitHub OIDC
│   │   ├── networking/     # VPC, subnets, NAT gateways, security groups
│   │   ├── eks/            # EKS cluster control plane and node groups
│   │   ├── eks-addons/     # EKS addons (VPC CNI, CoreDNS, EBS CSI driver)
│   │   └── iam/            # GitHub OIDC, IAM roles for IRSA
│   └── policies/           # Reusable IAM policy documents
├── terragrunt/             # Terragrunt configurations
│   ├── terragrunt.hcl      # Root configuration
│   └── environments/       # Environment-specific configs (staged deployment)
│       ├── dev/
│       │   ├── networking/     # Stage 1: VPC and networking
│       │   ├── eks-cluster/    # Stage 2: EKS control plane + nodes
│       │   ├── iam/            # Stage 3: IRSA roles
│       │   └── eks-addons/     # Stage 4: EKS addons
│       ├── qa/
│       └── prod/
├── scripts/                # Helper scripts
│   └── scale-workloads.sh  # Start/stop environments for cost optimization
├── k8s/                    # Kubernetes manifests
│   ├── workload-state/     # Replica count state per environment
│   └── base/               # Base K8s resources
└── helm/                   # Helm charts
    ├── backend/            # Backend service chart
    └── common/             # Shared library chart (tekmetric-common-chart)
```

## 🚀 Quick Start

> **New to this infrastructure?** Follow the **[Complete Setup Guide](SETUP-GUIDE.md)** for step-by-step instructions from AWS account creation to first deployment.

### For Existing Setups

If bootstrap is already complete and you're making changes:

Ensure the following are already configured:
- ✅ Bootstrap completed for all accounts (S3 backend, OIDC, IAM roles)
- ✅ GitHub secrets configured (AWS_*_ACCOUNT_ID, AWS_*_ROLE_ARN)
- ✅ Account IDs updated in `account.hcl` files

### Deploy Infrastructure Changes

**Option A: Via GitHub Actions (Recommended) - Staged Deployment**

The infrastructure uses a **staged deployment** approach with 4 sequential stages:

1. Go to **Actions → Terraform GitOps → Run workflow**
2. Select **Environment** (dev, qa, or prod)
3. Select **Stage**:
   - **1-networking**: VPC, subnets, NAT gateways
   - **2-eks-cluster**: EKS control plane and node groups
   - **3-iam**: IRSA roles for service accounts
   - **4-eks-addons**: EKS addons (EBS CSI driver, etc.)
4. Run each stage sequentially for a fresh deployment

**Fresh Deployment Example:**
```
1. Plan & Apply Stage 1-networking
2. Plan & Apply Stage 2-eks-cluster
3. Plan & Apply Stage 3-iam
4. Plan & Apply Stage 4-eks-addons
```

**Quick Update (existing infrastructure):**
```
Select Stage: all (runs all modules together)
```

**PR-Driven Deployment:**
1. Create a PR with infrastructure changes
2. Automatic plan runs for all stages
3. Use PR comments to control deployment:
   ```bash
   /terraform plan dev                # Plan all stages
   /terraform plan dev 1-networking   # Plan specific stage
   /terraform apply dev               # Apply all stages
   /terraform apply dev 3-iam         # Apply specific stage
   ```

📖 **For detailed staged deployment guide**, see [STAGED-DEPLOYMENT.md](./STAGED-DEPLOYMENT.md)

**Option B: Locally**

```bash
cd sre/terragrunt/environments/dev

# Staged deployment
cd networking && terragrunt plan && terragrunt apply
cd ../eks-cluster && terragrunt plan && terragrunt apply
cd ../iam && terragrunt plan && terragrunt apply
cd ../eks-addons && terragrunt plan && terragrunt apply

# Or all at once (if dependencies already exist)
terragrunt run-all plan
terragrunt run-all apply
```

## 🛠️ GitHub Workflows

### Infrastructure Management

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **sre-terraform-gitops** | Manual dispatch, PR comments, PRs | Deploy infrastructure with staged deployment support |
| **sre-environment-destroy** | Manual dispatch | Destroy all infrastructure (non-prod only) |

### Environment Lifecycle

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **sre-environment-start** | Manual dispatch | Scale workloads from 0 to saved replica counts |
| **sre-environment-stop** | Manual dispatch | Scale workloads to 0 (keeps infrastructure) |

### Application Delivery

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **service-backend-workflow** | Push to main, PRs | Build, test, scan, and publish backend service |
| **sre-helm-common-chart** | Push to main | Publish shared Helm library chart |

### Usage Examples

**Deploy infrastructure (staged approach)**:
```
Actions → Terraform GitOps → Environment: dev → Stage: 1-networking → Action: apply
(Repeat for stages 2-4)
```
📖 See [STAGED-DEPLOYMENT.md](./STAGED-DEPLOYMENT.md) for detailed guide

**Stop environment for cost savings (nights/weekends)**:
```
Actions → Stop Environment → Select environment → Run workflow
```
Saves ~50% on compute costs, infrastructure remains available.

**Start environment**:
```
Actions → Start Environment → Select environment → Run workflow
```
Restarts in minutes from saved state.

**Destroy environment completely**:
```
Actions → Destroy Environment → Select dev/qa → Type "destroy" → Run workflow
```
Complete teardown, 100% cost savings.

📖 **For complete workflow documentation**, see [GitHub Workflows README](../.github/workflows/README.md)

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

## 📖 Documentation

### Module Documentation

Detailed documentation for each Terraform module:

- [Bootstrap Module](terraform/modules/bootstrap/README.md) - S3 state backend, DynamoDB locks, GitHub OIDC setup
- [Networking Module](terraform/modules/networking/README.md) - VPC, subnets, NAT gateways, security groups
- [IAM Module](terraform/modules/iam/README.md) - GitHub OIDC provider and IRSA roles
- [EKS Module](terraform/modules/eks/README.md) - EKS cluster control plane and node groups
- EKS Addons Module - EKS addons (VPC CNI, CoreDNS, EBS CSI driver)

### Workflow Documentation

- [GitHub Actions Documentation](../.github/actions/README.md) - Custom composite actions
- [GitHub Workflows Documentation](../.github/workflows/README.md) - CI/CD workflows
- [Staged Deployment Guide](STAGED-DEPLOYMENT.md) - Infrastructure deployment strategy

## 📌 Version Management

### Kubernetes Version

K8s version is managed **per-environment** in `account.hcl` files:

```hcl
# environments/dev/account.hcl
locals {
  k8s_version = "1.34"  # Change here to upgrade dev
}
```

**To upgrade Kubernetes:**
1. Edit the environment's `account.hcl` file
2. Change `k8s_version` to desired version (e.g., "1.35")
3. Apply changes using staged deployment:
   ```bash
   # Plan to see upgrade path
   /terraform plan dev 2-eks-cluster
   /terraform plan dev 4-eks-addons

   # Apply EKS cluster upgrade
   /terraform apply dev 2-eks-cluster

   # Apply addons upgrade (must match cluster version)
   /terraform apply dev 4-eks-addons
   ```

**Progressive Rollout:**
- Week 1: Upgrade dev to test new version
- Week 2: Upgrade qa after validation
- Week 3: Upgrade prod after thorough testing

📖 See [Kubernetes Version Management](terragrunt/k8s-version-management.md) for details

## 🔧 Common Operations

### Managing EKS Access

The EKS clusters use IAM groups and roles for access management. Users added to the admin group can assume a role to get full cluster access.

#### Add User to EKS Admin Group

```bash
# Add a user to the EKS admin group
aws iam add-user-to-group \
  --user-name your-username \
  --group-name eks-dev-admins

# For other environments:
# --group-name eks-qa-admins
# --group-name eks-prod-admins
```

#### Get EKS Credentials

Once you're in the admin group, configure kubectl with role assumption:

```bash
# Update kubeconfig (automatically assumes the admin role)
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1 \
  --role-arn arn:aws:iam::YOUR_ACCOUNT_ID:role/tekmetric-dev-admins-role

# Verify access
kubectl get nodes
kubectl get pods -A
```

#### Remove User from EKS Admin Group

```bash
aws iam remove-user-from-group \
  --user-name your-username \
  --group-name eks-dev-admins
```

**How it works**: IAM Group → Can assume IAM Role → Role has EKS cluster admin access

See [EKS Module Documentation](terraform/modules/eks/README.md) for more details.

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

- [ ] Create AWS Organization with all features enabled
- [ ] Create sub-accounts (dev, qa, prod)
- [ ] Create IAM admin user in management account (not root!)
- [ ] Enable MFA on root and admin users
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

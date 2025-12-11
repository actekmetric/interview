# Complete Setup Guide - From Zero to Production

This guide walks you through setting up the entire infrastructure from scratch, starting with a fresh AWS account.

## Prerequisites

- AWS Root account access
- GitHub repository (this repo forked/cloned)
- GitHub repository admin access (for secrets)
- Local tools installed:
  - AWS CLI v2
  - Terraform >= 1.6.0
  - Git

## Architecture Decision: AWS Account Structure

### Recommended: AWS Organizations with Sub-Accounts

```
Root Account (Management)
├── Dev Sub-Account (123456789012)
├── QA Sub-Account (234567890123)
└── Prod Sub-Account (345678901234)
```

**Benefits:**
- Billing separation and cost tracking per environment
- Security isolation (compromise in dev doesn't affect prod)
- Independent IAM policies per environment
- Easier compliance and auditing

**Not Recommended: Single Account with IAM Users**
- No cost separation
- Higher blast radius for security incidents
- Complex IAM policies to separate environments

---

## Phase 1: AWS Account Setup

### Step 1.1: Create AWS Organization (if not exists)

1. Log into your AWS Root account
2. Navigate to **AWS Organizations**
3. Click **Create organization**
4. Choose **Enable all features**

### Step 1.2: Create Sub-Accounts

For each environment (dev, qa, prod):

1. In AWS Organizations, click **Add an AWS account**
2. Click **Create an AWS account**
3. Fill in:
   - **AWS account name**: `tekmetric-dev` (or qa/prod)
   - **Email**: `aws-dev@yourcompany.com` (must be unique per account)
   - **IAM role name**: `OrganizationAccountAccessRole`
4. Click **Create AWS account**
5. Wait for account creation (takes ~5 minutes)
6. **Note down the Account ID** (e.g., 123456789012)

Repeat for all three environments.

### Step 1.3: Access Sub-Accounts

**Option A: Switch Role from Root Account (Recommended)**

1. In AWS Console, click your username → **Switch Role**
2. Fill in:
   - **Account**: `123456789012` (dev account ID)
   - **Role**: `OrganizationAccountAccessRole`
   - **Display Name**: `Dev Account`
   - **Color**: Choose a color
3. Click **Switch Role**

You now have full admin access to the dev account without creating IAM users!

**Option B: IAM User in Sub-Account (Not Recommended)**

If you must create IAM users:
1. Switch to sub-account using Option A
2. Create IAM user with AdministratorAccess
3. Create access keys
4. **Delete this user after bootstrap is complete** (OIDC will replace it)

---

## Phase 2: Bootstrap Each Environment

Bootstrap creates the Terraform state backend and GitHub OIDC authentication. This is a **one-time manual process per account**.

### Step 2.1: Configure AWS CLI Profile

Create AWS CLI profiles for each sub-account:

```bash
# Edit ~/.aws/config
cat >> ~/.aws/config << 'EOF'

[profile dev]
role_arn = arn:aws:iam::123456789012:role/OrganizationAccountAccessRole
source_profile = default
region = us-east-1

[profile qa]
role_arn = arn:aws:iam::234567890123:role/OrganizationAccountAccessRole
source_profile = default
region = us-east-1

[profile prod]
role_arn = arn:aws:iam::345678901234:role/OrganizationAccountAccessRole
source_profile = default
region = us-east-1
EOF

# Test access
aws sts get-caller-identity --profile dev
```

**Expected Output:**
```json
{
  "UserId": "AIDAXXXXXXXXXXXXXXXXX:botocore-session-1234567890",
  "Account": "123456789012",
  "Arn": "arn:aws:sts::123456789012:assumed-role/OrganizationAccountAccessRole/botocore-session-1234567890"
}
```

### Step 2.2: Bootstrap Dev Account

```bash
cd sre/terraform/modules/bootstrap

# Initialize Terraform (uses LOCAL state for first run)
terraform init

# Plan the bootstrap
terraform plan \
  -var="environment=dev" \
  -var="account_id=123456789012" \
  -var="region=us-east-1" \
  -var="github_org=your-github-org" \
  -var="github_repo=your-repo-name" \
  -var="enable_github_oidc=true"

# Apply the bootstrap
AWS_PROFILE=dev terraform apply \
  -var="environment=dev" \
  -var="account_id=123456789012" \
  -var="region=us-east-1" \
  -var="github_org=your-github-org" \
  -var="github_repo=your-repo-name" \
  -var="enable_github_oidc=true"
```

**What Gets Created:**
- ✅ S3 bucket: `tekmetric-terraform-state-123456789012`
- ✅ DynamoDB table: `tekmetric-terraform-locks-123456789012`
- ✅ GitHub OIDC provider
- ✅ IAM role: `GitHubActionsRole-dev`

**Important Outputs - Save These:**
```bash
# Copy these outputs, you'll need them later
terraform output github_actions_role_arn
# Output: arn:aws:iam::123456789012:role/GitHubActionsRole-dev

terraform output state_bucket_name
# Output: tekmetric-terraform-state-123456789012
```

### Step 2.3: Migrate Bootstrap State to S3

**Important:** The bootstrap just created the S3 bucket, but its own state is still local. Migrate it to S3:

```bash
# Still in sre/terraform/modules/bootstrap

# Create backend configuration
cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "tekmetric-terraform-state-123456789012"
    key            = "bootstrap/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tekmetric-terraform-locks-123456789012"
    encrypt        = true
  }
}
EOF

# Migrate state to S3
AWS_PROFILE=dev terraform init -migrate-state

# When prompted: "Do you want to copy existing state to the new backend?"
# Answer: yes

# Verify state is in S3
aws s3 ls s3://tekmetric-terraform-state-123456789012/bootstrap/ --profile dev

# Clean up local state files
rm -f terraform.tfstate terraform.tfstate.backup

# ⚠️ IMPORTANT: Never commit terraform.tfstate files to git
echo "*.tfstate" >> .gitignore
echo "*.tfstate.backup" >> .gitignore
```

### Step 2.4: Bootstrap QA and Prod

Repeat Steps 2.2 and 2.3 for QA and Prod:

```bash
# QA Account
AWS_PROFILE=qa terraform apply \
  -var="environment=qa" \
  -var="account_id=234567890123" \
  -var="region=us-east-1" \
  -var="github_org=your-github-org" \
  -var="github_repo=your-repo-name" \
  -var="enable_github_oidc=true"

# Migrate QA state (update bucket name in backend.tf first)

# Prod Account
AWS_PROFILE=prod terraform apply \
  -var="environment=prod" \
  -var="account_id=345678901234" \
  -var="region=us-east-1" \
  -var="github_org=your-github-org" \
  -var="github_repo=your-repo-name" \
  -var="enable_github_oidc=true"

# Migrate prod state (update bucket name in backend.tf first)
```

---

## Phase 3: Configure GitHub Repository

### Step 3.1: Configure GitHub Secrets

Navigate to your GitHub repository: **Settings → Secrets and variables → Actions**

Add these **Repository Secrets** (from bootstrap outputs):

```bash
# Dev Environment
AWS_DEV_ACCOUNT_ID=123456789012
AWS_DEV_ROLE_ARN=arn:aws:iam::123456789012:role/GitHubActionsRole-dev

# QA Environment
AWS_QA_ACCOUNT_ID=234567890123
AWS_QA_ROLE_ARN=arn:aws:iam::234567890123:role/GitHubActionsRole-qa

# Prod Environment
AWS_PROD_ACCOUNT_ID=345678901234
AWS_PROD_ROLE_ARN=arn:aws:iam::345678901234:role/GitHubActionsRole-prod
```

**Note:** No AWS access keys or secrets needed! GitHub OIDC provides temporary credentials automatically.

### Step 3.2: Update Terragrunt Configuration

Update account IDs in terragrunt configs:

**File: `sre/terragrunt/environments/dev/account.hcl`**
```hcl
locals {
  account_id  = "123456789012"  # Your actual dev account ID
  environment = "dev"
  region      = "us-east-1"
}
```

**File: `sre/terragrunt/environments/qa/account.hcl`**
```hcl
locals {
  account_id  = "234567890123"  # Your actual qa account ID
  environment = "qa"
  region      = "us-east-1"
}
```

**File: `sre/terragrunt/environments/prod/account.hcl`**
```hcl
locals {
  account_id  = "345678901234"  # Your actual prod account ID
  environment = "prod"
  region      = "us-east-1"
}
```

### Step 3.3: Commit and Push Changes

```bash
git add sre/terragrunt/environments/*/account.hcl
git commit -m "Configure account IDs for dev, qa, prod"
git push origin main
```

---

## Phase 4: First Infrastructure Deployment

### Step 4.1: Deploy Dev Environment (Staged Approach)

Go to GitHub: **Actions → Terraform GitOps → Run workflow**

**Stage 1: Networking**
- Environment: `dev`
- Action: `plan`
- Stage: `1-networking`
- Click **Run workflow**
- Review the plan output
- Run again with Action: `apply`

**Wait for Stage 1 to Complete (~5 minutes)**

**Stage 2: EKS Cluster**
- Environment: `dev`
- Action: `plan`
- Stage: `2-eks-cluster`
- Review and apply

**Wait for Stage 2 to Complete (~15 minutes)**

**Stage 3: IAM**
- Environment: `dev`
- Action: `plan`
- Stage: `3-iam`
- Review and apply

**Wait for Stage 3 to Complete (~2 minutes)**

**Stage 4: EKS Addons**
- Environment: `dev`
- Action: `plan`
- Stage: `4-eks-addons`
- Review and apply

**Wait for Stage 4 to Complete (~5 minutes)**

### Step 4.2: Verify Deployment

```bash
# Configure kubectl
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1 \
  --profile dev

# Check cluster
kubectl get nodes
kubectl get pods -A

# Expected: 2-3 nodes running, system pods in kube-system namespace
```

### Step 4.3: Deploy QA and Prod

Repeat Step 4.1 for QA and Prod environments using the same staged approach.

**Recommended Order:**
1. Dev (test everything here first)
2. QA (after dev is stable)
3. Prod (after QA is validated)

---

## Phase 5: Access Management

### Step 5.1: Add Users to EKS Admin Group

The infrastructure creates IAM groups for EKS access. Add your team members:

```bash
# Create IAM user (if they don't exist)
aws iam create-user --user-name john.doe --profile dev

# Add user to EKS admin group
aws iam add-user-to-group \
  --user-name john.doe \
  --group-name eks-dev-admins \
  --profile dev

# User can now access the cluster by assuming the role
```

### Step 5.2: User Access Instructions

Send this to users who need EKS access:

```bash
# Configure AWS CLI profile with role assumption
cat >> ~/.aws/config << 'EOF'

[profile dev-eks]
role_arn = arn:aws:iam::123456789012:role/tekmetric-dev-admins-role
source_profile = default
region = us-east-1
EOF

# Get EKS credentials
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1 \
  --profile dev-eks

# Verify access
kubectl get nodes
```

---

## Phase 6: Cleanup Bootstrap Credentials (Optional)

If you created IAM users for bootstrap (not recommended), delete them now:

```bash
# OIDC has replaced the need for IAM users
# GitHub Actions now uses temporary credentials

# Delete IAM user access keys
aws iam delete-access-key \
  --user-name bootstrap-user \
  --access-key-id AKIAXXXXXXXXXXXXXXXX \
  --profile dev

# Delete IAM user
aws iam delete-user \
  --user-name bootstrap-user \
  --profile dev
```

**From now on, all deployments use GitHub OIDC** - no static credentials needed!

---

## What Happens After First Deployment?

### Automated Workflows

Once infrastructure is deployed, these workflows run automatically:

1. **PR Created** → Terraform plan runs automatically
2. **PR Merged** → Infrastructure changes applied (if using push trigger)
3. **Backend Code Push** → Build, test, scan, publish Docker image and Helm chart
4. **Manual Workflows** → Start/stop/destroy environments for cost optimization

### PR-Driven Deployments

```bash
# Make infrastructure changes
git checkout -b feature/add-monitoring
# ... edit terraform files ...
git commit -m "Add CloudWatch monitoring"
git push origin feature/add-monitoring

# Create PR → Terraform plan runs automatically (all stages in dev)
# Review plan in PR comments

# Option 1: Apply all stages
/terraform apply dev

# Option 2: Apply specific stage only (if change is isolated)
/terraform apply dev 3-iam          # If you only changed IAM

# Option 3: Plan specific stage first
/terraform plan dev 2-eks-cluster   # Preview only EKS changes
/terraform apply dev 2-eks-cluster  # Then apply

# PR Comment Syntax:
# /terraform <action> [environment] [stage]
# - Defaults: environment=dev, stage=all
```

### Cost Optimization Workflows

```bash
# Stop dev environment at night (saves ~50% compute cost)
Actions → Stop Environment → dev

# Start dev environment in morning
Actions → Start Environment → dev

# Destroy QA after testing (saves 100%)
Actions → Destroy Environment → qa → Type "destroy"
```

---

## Troubleshooting Common Issues

### Issue: "Error assuming role"

**Cause:** OIDC provider not configured or wrong GitHub repo

**Solution:**
```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers --profile dev

# Check trust policy
aws iam get-role --role-name GitHubActionsRole-dev --profile dev

# Verify GitHub repo name matches exactly
```

### Issue: "Bucket already exists"

**Cause:** Bootstrap was partially applied before

**Solution:**
```bash
# Import existing resources
terraform import aws_s3_bucket.terraform_state tekmetric-terraform-state-123456789012
terraform import aws_dynamodb_table.terraform_locks tekmetric-terraform-locks-123456789012
```

### Issue: "No outputs detected" during staged deployment

**Cause:** Previous stage wasn't applied yet

**Solution:** Apply stages in order: 1 → 2 → 3 → 4. Don't skip stages.

### Issue: "Access Denied" when deploying

**Cause:** GitHub secrets not configured correctly

**Solution:** Verify secrets match bootstrap outputs:
```bash
# Get correct values
cd sre/terraform/modules/bootstrap
terraform output github_actions_role_arn
terraform output state_bucket_name

# Update GitHub secrets to match
```

---

## Quick Reference: Setup Checklist

- [ ] Create AWS Organization and sub-accounts (dev, qa, prod)
- [ ] Note down account IDs
- [ ] Configure AWS CLI profiles for each account
- [ ] Bootstrap dev account (terraform apply)
- [ ] Migrate dev bootstrap state to S3
- [ ] Bootstrap qa account
- [ ] Migrate qa bootstrap state to S3
- [ ] Bootstrap prod account
- [ ] Migrate prod bootstrap state to S3
- [ ] Configure GitHub secrets (6 secrets total)
- [ ] Update account.hcl files with real account IDs
- [ ] Commit and push changes
- [ ] Deploy dev infrastructure (4 stages)
- [ ] Verify dev deployment (kubectl)
- [ ] Deploy qa infrastructure
- [ ] Deploy prod infrastructure
- [ ] Add users to EKS admin groups
- [ ] Delete bootstrap IAM users (if created)
- [ ] Test PR-driven workflow
- [ ] Document custom configurations for your team

---

## Next Steps

- **Read**: [STAGED-DEPLOYMENT.md](STAGED-DEPLOYMENT.md) for deployment strategies
- **Review**: [GitHub Workflows Documentation](../.github/workflows/README.md)
- **Customize**: Adjust node sizes, instance types for your workload
- **Monitor**: Set up CloudWatch alerts and dashboards
- **Optimize**: Use spot instances in dev/qa for cost savings

---

## Support

For issues or questions:
- Infrastructure setup: Review this guide step by step
- Terraform errors: Check [Module README files](terraform/modules/)
- GitHub Actions: Check [Workflows README](../.github/workflows/README.md)
- AWS-specific: Review AWS CloudTrail logs for detailed error messages

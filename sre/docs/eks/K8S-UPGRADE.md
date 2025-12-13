# Kubernetes Version Management

## Overview

Kubernetes version is managed **per-environment** in the `account.hcl` file. This allows each environment to run different K8s versions for progressive rollout and testing.

## Current Versions

Check current versions in each environment:

```bash
# Dev
grep k8s_version environments/dev/account.hcl

# QA
grep k8s_version environments/qa/account.hcl

# Prod
grep k8s_version environments/prod/account.hcl
```

## How to Upgrade Kubernetes

### Step 1: Update Version in account.hcl

Edit the target environment's account file:

```bash
# For dev environment
vim sre/terragrunt/environments/dev/account.hcl
```

Change the version:
```hcl
locals {
  environment = "dev"
  account_id  = "096610237522"

  # Kubernetes version
  k8s_version = "1.35"  # Changed from "1.34"

  # Other settings...
}
```

### Step 2: Plan the Upgrade

Review what will change:

```bash
# Via GitHub Actions (PR comment)
/terraform plan dev 2-eks-cluster
/terraform plan dev 4-eks-addons

# Or locally
cd sre/terragrunt/environments/dev/eks-cluster
terragrunt plan

cd ../eks-addons
terragrunt plan
```

### Step 3: Apply the Upgrade

**Important:** Upgrade in this order:
1. EKS cluster first
2. EKS addons second (must match cluster version)

```bash
# Via GitHub Actions (PR comment)
/terraform apply dev 2-eks-cluster
# Wait for cluster upgrade to complete
/terraform apply dev 4-eks-addons

# Or via GitHub Actions UI
Actions → Terraform GitOps → Run workflow
- Environment: dev
- Action: apply
- Stage: 2-eks-cluster
# Then repeat for stage 4-eks-addons

# Or locally
cd sre/terragrunt/environments/dev/eks-cluster
terragrunt apply

cd ../eks-addons
terragrunt apply
```

### Step 4: Verify Upgrade

```bash
# Check cluster version
aws eks describe-cluster --name tekmetric-dev \
  --query 'cluster.version' --output text

# Check nodes are running
kubectl get nodes

# Check addons version
aws eks list-addons --cluster-name tekmetric-dev
```

## Progressive Rollout Strategy

Recommended approach for upgrading across environments:

### Week 1: Dev Environment
```bash
# Update dev to new version
vim environments/dev/account.hcl
# k8s_version = "1.35"

# Apply and test
/terraform apply dev 2-eks-cluster
/terraform apply dev 4-eks-addons

# Test applications, validate workloads
```

### Week 2: QA Environment
```bash
# After dev validation, update qa
vim environments/qa/account.hcl
# k8s_version = "1.35"

# Apply and validate
/terraform apply qa 2-eks-cluster
/terraform apply qa 4-eks-addons

# Run full test suite
```

### Week 3: Production
```bash
# After thorough testing, update prod
vim environments/prod/account.hcl
# k8s_version = "1.35"

# Apply during maintenance window
/terraform apply prod 2-eks-cluster
/terraform apply prod 4-eks-addons

# Monitor closely
```

## Where Version is Used

The `k8s_version` from `account.hcl` is automatically passed to:
- EKS cluster module (`eks-cluster/`) - Sets cluster version
- EKS addons module (`eks-addons/`) - Ensures addon compatibility

Both modules receive the same version to maintain consistency.

## EKS Version Support

- AWS supports N, N-1, N-2 versions (e.g., 1.34, 1.33, 1.32)
- Versions are supported for ~14 months
- Plan upgrades before automatic forced upgrades
- Check [AWS EKS version calendar](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)

## Important Notes

### Version Compatibility
- ⚠️ EKS addons must match cluster version
- ⚠️ Upgrading cluster without upgrading addons will cause failures
- ⚠️ Always upgrade both eks-cluster and eks-addons modules

### Upgrade Impact
- Cluster upgrade causes brief control plane unavailability (~10-15 min)
- Node upgrades are rolling (workloads remain available with proper PDBs)
- Addons restart during upgrade

### Testing
Before upgrading production:
- ✅ Test in dev environment first
- ✅ Validate all applications work
- ✅ Check deprecated APIs (use kubectl convert or pluto)
- ✅ Review [Kubernetes version skew policy](https://kubernetes.io/releases/version-skew-policy/)

## Rollback

If upgrade causes issues:

```bash
# Revert version in account.hcl
vim environments/dev/account.hcl
# k8s_version = "1.34"  # Back to previous version

# Apply rollback (creates new cluster - destructive!)
/terraform apply dev 2-eks-cluster
/terraform apply dev 4-eks-addons
```

⚠️ **Note:** EKS doesn't support downgrading clusters. Rollback requires cluster recreation.

**Better approach:** Always test in dev first to avoid prod rollbacks.

## Troubleshooting

### Issue: Addon fails to install after cluster upgrade

**Cause:** Addon version incompatible with cluster version

**Solution:**
```bash
# Ensure addons are upgraded after cluster
cd environments/dev/eks-addons
terragrunt apply
```

### Issue: Nodes stuck in old version

**Cause:** Node group update didn't trigger

**Solution:**
```bash
# Check node group version
aws eks describe-nodegroup --cluster-name tekmetric-dev \
  --nodegroup-name <nodegroup-name>

# Force node group update
cd environments/dev/eks-cluster
terragrunt apply -replace='aws_eks_node_group.main["general"]'
```

### Issue: Applications fail after upgrade

**Cause:** Deprecated APIs removed in new K8s version

**Solution:**
```bash
# Check for deprecated APIs before upgrading
kubectl get all -A -o yaml | pluto detect -

# Or use kubectl-convert
kubectl convert -f old-manifest.yaml --output-version apps/v1
```

## Quick Reference

```bash
# View current version
grep k8s_version environments/dev/account.hcl

# Update version
vim environments/dev/account.hcl

# Plan upgrade
/terraform plan dev 2-eks-cluster
/terraform plan dev 4-eks-addons

# Apply upgrade
/terraform apply dev 2-eks-cluster
/terraform apply dev 4-eks-addons

# Verify
aws eks describe-cluster --name tekmetric-dev --query 'cluster.version'
kubectl get nodes
```

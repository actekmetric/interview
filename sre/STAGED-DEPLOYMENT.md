# Staged Terraform Deployments

## Overview

The Terraform GitOps workflow now supports staged deployments, allowing you to plan and apply infrastructure in 4 sequential stages. This eliminates the complexity of mock outputs and dependency management.

## Deployment Stages

1. **1-networking** - VPC, subnets, NAT gateways, security groups
2. **2-eks-cluster** - EKS cluster control plane + node groups (no addons)
3. **3-iam** - IRSA roles for EKS service accounts
4. **4-eks-addons** - EKS addons (VPC CNI, CoreDNS, kube-proxy, EBS CSI driver)

## Usage

### GitHub Actions UI

Go to **Actions → Terraform GitOps → Run workflow**

Select:
- **Environment**: dev / qa / prod
- **Action**: plan / apply
- **Stage**:
  - `all` - Run all stages (uses `terragrunt run-all`)
  - `1-networking` - Only networking module
  - `2-eks-cluster` - Only EKS cluster module
  - `3-iam` - Only IAM module
  - `4-eks-addons` - Only EKS addons module

### Typical Deployment Flow

#### Full Fresh Deployment

Run these **4 times for plan**, then **4 times for apply**:

```
1. Plan → Stage: 1-networking → Environment: dev
2. Plan → Stage: 2-eks-cluster → Environment: dev
3. Plan → Stage: 3-iam → Environment: dev
4. Plan → Stage: 4-eks-addons → Environment: dev

Then:

5. Apply → Stage: 1-networking → Environment: dev
6. Apply → Stage: 2-eks-cluster → Environment: dev
7. Apply → Stage: 3-iam → Environment: dev
8. Apply → Stage: 4-eks-addons → Environment: dev
```

#### Quick All-in-One (if infrastructure already exists)

```
1. Plan → Stage: all → Environment: dev
2. Apply → Stage: all → Environment: dev
```

#### Update Single Module

```
1. Plan → Stage: 3-iam → Environment: dev
2. Apply → Stage: 3-iam → Environment: dev
```

## Benefits

✅ **No Mock Outputs** - Each stage depends on previous stage being applied
✅ **Clear Dependencies** - Explicit deployment order
✅ **Granular Control** - Deploy only what changed
✅ **Faster Iterations** - Don't wait for full `run-all`
✅ **Easier Debugging** - Test each stage independently

## Stage Dependencies

```
networking (no dependencies)
    ↓
eks-cluster (needs networking outputs)
    ↓
iam (needs eks-cluster OIDC URL)
    ↓
eks-addons (needs eks-cluster + iam role ARNs)
```

## When to Use Each Stage

### Stage 1: networking
- First time setup
- VPC changes
- Subnet modifications
- Security group updates

### Stage 2: eks-cluster
- EKS version upgrades
- Node group changes
- Cluster configuration updates
- Enable/disable IRSA

### Stage 3: iam
- After enabling IRSA on cluster
- Adding new service account roles
- Updating IAM policies

### Stage 4: eks-addons
- After IAM roles are created
- Addon version updates
- Adding new addons

## Example: Enable IRSA (Two-Phase Deployment)

**Phase 1: Cluster + IAM**
```
1. Plan → Stage: 2-eks-cluster (with enable_irsa = true)
2. Apply → Stage: 2-eks-cluster
3. Plan → Stage: 3-iam (with enable_irsa_roles = true)
4. Apply → Stage: 3-iam
```

**Phase 2: Addons**
```
5. Plan → Stage: 4-eks-addons
6. Apply → Stage: 4-eks-addons
```

## Pull Request Workflow

On PR creation/update:
- Automatically runs `plan` with `stage: all` on dev environment
- Shows plan output in PR comment

**PR Comments Support Stage Specification:**
```bash
/terraform plan dev                # Plan all stages (default)
/terraform plan dev 1-networking   # Plan only networking
/terraform apply dev               # Apply all stages
/terraform apply dev 3-iam         # Apply only IAM stage
/terraform apply qa 2-eks-cluster  # Apply EKS cluster in QA

# Syntax: /terraform <action> [environment] [stage]
# Defaults: environment=dev, stage=all
```

## Tips

- **Always plan before apply** - Even if you ran plan earlier, state may have changed
- **Run stages in order** - Don't skip stages (1 → 2 → 3 → 4)
- **Use "all" for small changes** - If just updating a variable, `stage: all` is fine
- **Use specific stages for major changes** - New modules, big refactors, etc.

## Troubleshooting

**Error: "No outputs detected"**
- Previous stage hasn't been applied yet
- Solution: Apply the previous stage first

**Error: "Module not found"**
- Check stage name matches directory name
- Valid: `1-networking`, `2-eks-cluster`, `3-iam`, `4-eks-addons`
- Invalid: `networking`, `eks`, `1-eks-cluster`

**Terraform state lock**
- Another workflow is running
- Wait for it to complete or check DynamoDB locks table

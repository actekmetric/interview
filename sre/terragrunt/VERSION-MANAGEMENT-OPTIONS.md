# Kubernetes Version Management - Centralization Options

## Current State

**Problem:** K8s version `1.34` is hardcoded in **6 different files**:

```
sre/terragrunt/environments/
├── dev/
│   ├── eks-cluster/terragrunt.hcl   → cluster_version = "1.34"
│   └── eks-addons/terragrunt.hcl    → cluster_version = "1.34"
├── qa/
│   ├── eks-cluster/terragrunt.hcl   → cluster_version = "1.34"
│   └── eks-addons/terragrunt.hcl    → cluster_version = "1.34"
└── prod/
    ├── eks-cluster/terragrunt.hcl   → cluster_version = "1.34"
    └── eks-addons/terragrunt.hcl    → cluster_version = "1.34"
```

**Pain Points:**
- To upgrade K8s, must update 6 files
- Risk of version mismatch between eks-cluster and eks-addons
- No single source of truth

---

## Option 1: Root Terragrunt Configuration (Recommended)

### Implementation

**File: `sre/terragrunt/terragrunt.hcl`**

Add to `locals` block:
```hcl
locals {
  # Existing locals...
  environment = local.environment_vars.locals.environment
  account_id  = local.environment_vars.locals.account_id
  region      = local.region_vars.locals.region

  # NEW: Global K8s version
  k8s_version = "1.34"

  # Global tags...
}
```

Add to `inputs` block:
```hcl
inputs = merge(
  local.common_tags,
  {
    environment     = local.environment
    account_id      = local.account_id
    region          = local.region
    k8s_version     = local.k8s_version  # NEW
  }
)
```

**Child modules update:**

All 6 files change from:
```hcl
inputs = {
  cluster_version = "1.34"  # OLD - hardcoded
}
```

To:
```hcl
inputs = {
  cluster_version = local.k8s_version  # NEW - from root
}
```

### Pros
✅ Single source of truth (root terragrunt.hcl)
✅ All environments use same K8s version automatically
✅ Upgrade = change 1 line in root file
✅ Consistent across cluster and addons
✅ Already follows pattern (environment, account_id, region)

### Cons
❌ All environments must use same K8s version
❌ Can't have prod on 1.33 while dev tests 1.34

### Use Case
Perfect for: **Organizations that upgrade all environments together**

---

## Option 2: Per-Environment Version (account.hcl)

### Implementation

**File: `sre/terragrunt/environments/dev/account.hcl`**
```hcl
locals {
  environment = "dev"
  account_id  = "096610237522"

  # NEW: Environment-specific K8s version
  k8s_version = "1.34"

  # Other environment settings...
  single_nat_gateway = true
}
```

Repeat for qa/account.hcl and prod/account.hcl.

**Root terragrunt.hcl:**
```hcl
locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  k8s_version      = local.environment_vars.locals.k8s_version  # NEW
}

inputs = merge(
  local.common_tags,
  {
    k8s_version = local.k8s_version  # NEW
  }
)
```

**Child modules:**
```hcl
inputs = {
  cluster_version = local.k8s_version  # From account.hcl via root
}
```

### Pros
✅ Per-environment K8s versions
✅ Upgrade dev to 1.35, keep prod on 1.34
✅ Progressive rollout strategy
✅ Still only 1 change per environment (account.hcl)

### Cons
❌ 3 places to manage (dev/qa/prod account.hcl)
❌ Risk of accidentally using different versions

### Use Case
Perfect for: **Organizations that test K8s upgrades in dev first**

---

## Option 3: Hybrid - Global Default + Environment Override

### Implementation

**Root terragrunt.hcl:**
```hcl
locals {
  # Default K8s version (used if not overridden)
  default_k8s_version = "1.34"

  environment_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  # Use environment override if exists, otherwise use default
  k8s_version = try(local.environment_vars.locals.k8s_version, local.default_k8s_version)
}
```

**Account.hcl (optional override):**
```hcl
locals {
  # Only define if you want to override default
  # k8s_version = "1.35"  # Uncomment to override
}
```

### Pros
✅ Best of both worlds
✅ Default in root = all environments consistent
✅ Override in account.hcl = per-environment flexibility
✅ Progressive upgrades possible
✅ Most environments use default (DRY principle)

### Cons
❌ More complex logic
❌ Need to understand override mechanism
❌ Can forget which environment has override

### Use Case
Perfect for: **Organizations that usually upgrade together, but occasionally need testing in one environment**

---

## Option 4: Version Map (Advanced)

### Implementation

**Root terragrunt.hcl:**
```hcl
locals {
  # K8s version map
  k8s_versions = {
    dev  = "1.35"  # Testing new version
    qa   = "1.34"  # Stable
    prod = "1.34"  # Production
  }

  k8s_version = local.k8s_versions[local.environment]
}
```

### Pros
✅ All versions visible in one place
✅ Per-environment versions
✅ Easy to see version drift
✅ Single file to manage

### Cons
❌ Still 3 versions to manage (just in one place)
❌ Need to remember to update map

### Use Case
Perfect for: **Organizations with strict version control and want visibility**

---

## Recommendation Matrix

| Scenario | Recommended Option | Reason |
|----------|-------------------|---------|
| **Small team, simple upgrades** | Option 1 (Root) | Simplest, all envs same version |
| **Progressive K8s upgrades** | Option 2 (Per-env) | Test in dev, then qa, then prod |
| **Occasional testing** | Option 3 (Hybrid) | Default consistency + flexibility |
| **Large org, strict control** | Option 4 (Version map) | Visibility and centralized control |
| **Compliance-heavy** | Option 2 or 4 | Explicit per-environment versions |

---

## Migration Plan (Generic)

Regardless of option chosen:

### Step 1: Add Version to Root/Account
- Add k8s_version local to appropriate file
- Don't remove hardcoded versions yet

### Step 2: Update Child Modules
- Change hardcoded `"1.34"` to `local.k8s_version`
- Test with `terragrunt plan` (should show no changes)

### Step 3: Verify No Changes
```bash
cd sre/terragrunt/environments/dev/eks-cluster
terragrunt plan  # Should show: No changes. Your infrastructure matches the configuration.

cd ../eks-addons
terragrunt plan  # Should show: No changes.
```

Repeat for qa and prod.

### Step 4: Test Version Change
- Change version in root/account.hcl
- Run plan to see upgrade path
- Revert if not ready

---

## Real-World Example: Option 1 Implementation

### Before (6 files to change):
```hcl
# dev/eks-cluster/terragrunt.hcl
inputs = {
  cluster_version = "1.34"
}

# dev/eks-addons/terragrunt.hcl
inputs = {
  cluster_version = "1.34"
}

# ... 4 more files ...
```

### After (1 file to change):
```hcl
# Root: sre/terragrunt/terragrunt.hcl
locals {
  k8s_version = "1.34"  # <-- Change once here
}

# All 6 child files:
inputs = {
  cluster_version = local.k8s_version  # <-- References root
}
```

### Upgrade Process:
```bash
# Change 1 line
vim sre/terragrunt/terragrunt.hcl
# Change: k8s_version = "1.34" → "1.35"

# All environments now use 1.35
```

---

## Considerations

### EKS Version Support
- AWS supports N, N-1, N-2 versions
- Current: 1.31, 1.32, 1.33, 1.34
- Upgrade window: ~14 months before forced upgrade

### Addon Compatibility
- EKS addons must match cluster version
- Having cluster_version in both modules ensures consistency
- Mismatched versions cause addon failures

### Blue/Green Upgrades
- For zero-downtime upgrades, need separate clusters
- Version management still applies per cluster
- Consider naming: `tekmetric-dev-blue` vs `tekmetric-dev-green`

---

## Questions to Answer Before Choosing

1. **Do all environments always run the same K8s version?**
   - Yes → Option 1 (Root)
   - No → Option 2 or 3

2. **Do you test K8s upgrades in dev first?**
   - Yes → Option 2 or 3
   - No → Option 1

3. **How often do you upgrade K8s?**
   - Rarely (annually) → Option 1 (simpler)
   - Frequently (quarterly) → Option 2 or 3 (more control)

4. **Do you have compliance requirements?**
   - Yes → Option 2 or 4 (explicit per-env)
   - No → Option 1 or 3 (simpler)

5. **Team size and change management?**
   - Small team → Option 1 (simpler)
   - Large team → Option 4 (visibility)

---

## Next Steps

1. **Choose an option** based on your organization's needs
2. **Review with team** if multiple people manage infrastructure
3. **Test in dev** before rolling out pattern
4. **Document decision** in this file for future reference
5. **Implement gradually** - one environment at a time

---

## Decision Record

**Date:** 2025-12-11
**Chosen Option:** Option 2 - Per-Environment Version (account.hcl)
**Reasoning:**
- Follows existing pattern (environment, account_id are per-environment)
- Enables progressive K8s upgrades (test in dev, rollout to qa, then prod)
- Only 3 files to manage (one per environment)
- Clean and consistent with established conventions
**Implemented By:** Infrastructure automation
**Rollback Plan:** Revert to hardcoded versions in child terragrunt.hcl files if needed

## Implementation Summary

**Files Modified:**

1. **Account Configuration (3 files):**
   - `environments/dev/account.hcl` - Added `k8s_version = "1.34"`
   - `environments/qa/account.hcl` - Added `k8s_version = "1.34"`
   - `environments/prod/account.hcl` - Added `k8s_version = "1.34"`

2. **Root Configuration:**
   - `terragrunt.hcl` - Reads `k8s_version` from account.hcl and exposes it

3. **Child Modules (6 files):**
   - `environments/*/eks-cluster/terragrunt.hcl` - Changed to `cluster_version = local.k8s_version`
   - `environments/*/eks-addons/terragrunt.hcl` - Changed to `cluster_version = local.k8s_version`

**Upgrade Process:**

To upgrade Kubernetes version for an environment:
```bash
# Edit the environment's account.hcl
vim sre/terragrunt/environments/dev/account.hcl
# Change: k8s_version = "1.34" → "1.35"

# Plan the upgrade
cd sre/terragrunt/environments/dev
terragrunt run-all plan  # See what changes

# Apply (staged approach recommended)
# Stage 2: EKS cluster upgrade
cd eks-cluster && terragrunt apply

# Stage 4: EKS addons upgrade (match cluster version)
cd ../eks-addons && terragrunt apply
```

**Progressive Rollout Example:**
```bash
# Week 1: Upgrade dev to 1.35
vim environments/dev/account.hcl  # k8s_version = "1.35"

# Week 2: After testing, upgrade qa
vim environments/qa/account.hcl   # k8s_version = "1.35"

# Week 3: After validation, upgrade prod
vim environments/prod/account.hcl # k8s_version = "1.35"
```

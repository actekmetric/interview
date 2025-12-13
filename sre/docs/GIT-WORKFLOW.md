# Git Workflow - Branch-Based Deployments

## Overview

This repository uses a **branch-based deployment strategy** where the branch name automatically determines which environment your code deploys to. This provides fast feedback for development while maintaining safety for production releases.

## Branch Strategy

```
develop          → dev       Auto-deploys for fast feedback
release/*        → qa        Auto-deploys for testing
master/main      → prod      Manual approval required
feature/*        → none      Build/test only, no deploy
hotfix/*         → dev       Test urgent fixes
```

## Branch-to-Environment Mapping

| Branch Pattern | Environment | Auto-Deploy | Version Pattern | When to Use |
|----------------|-------------|-------------|-----------------|-------------|
| `develop` | dev | ✅ Yes | `1.0.0.123-abc1234-dev` | Active development, immediate feedback |
| `release/v*` | qa | ✅ Yes | `1.0.0.123-abc1234-rc` | Release candidates for QA testing |
| `master`/`main` | prod | ❌ Manual | `1.0.0.123-abc1234` | Production releases |
| `feature/*` | none | ❌ No | `1.0.0.123-abc1234-feature-{name}` | Work in progress, PR to develop |
| `hotfix/*` | dev | ⚠️  Optional | `1.0.0.123-abc1234-hotfix-{name}` | Urgent production fixes |

## How It Works

### Automatic Version Tagging

The CI pipeline automatically generates version tags based on the branch:

- **develop**: `1.0.0.456-abc1234-dev`
- **release/v2.0**: `1.0.0.456-abc1234-rc`
- **master**: `1.0.0.456-abc1234`
- **feature/user-api**: `1.0.0.456-abc1234-feature-user-api`
- **hotfix/bug-fix**: `1.0.0.456-abc1234-hotfix-bug-fix`

### Automatic Environment Selection

The CD pipeline reads the branch name and automatically deploys to the appropriate environment:

- Push to **develop** → Builds → Auto-deploys to **dev**
- Push to **release/** → Builds → Auto-deploys to **qa**
- Push to **master** → Builds → Waits for manual approval → Deploys to **prod**
- Push to **feature/** → Builds → No deployment
- Push to **hotfix/** → Builds → Auto-deploys to **dev**

## Common Workflows

### 1. Feature Development

**Scenario:** You're adding a new API endpoint

```bash
# 1. Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/add-user-api

# 2. Make changes and commit
# ... make your changes ...
git add .
git commit -m "Add user API endpoint"
git push origin feature/add-user-api

# 3. Create Pull Request to develop
# - CI runs: build, test, security scan
# - No deployment happens
# - After approval and merge to develop:
#   → CI builds image with -dev tag
#   → CD auto-deploys to dev environment
#   → You can test in dev immediately
```

**What happens:**
- ✅ CI builds and tests your code
- ✅ Security scanning runs
- ❌ **No deployment** (feature branches don't deploy)
- After merge to develop:
  - ✅ Image: `backend:1.0.0.123-abc1234-dev`
  - ✅ Auto-deploys to **dev** environment
  - ✅ Available for testing in ~5 minutes

### 2. Preparing a Release

**Scenario:** Ready to release version 2.0.0 to production

```bash
# 1. Create release branch from develop
git checkout develop
git pull origin develop
git checkout -b release/v2.0.0

# 2. (Optional) Bump version in pom.xml if needed
# <version>2.0.0</version>

# 3. Push release branch
git push origin release/v2.0.0

# What happens automatically:
# - CI builds image: backend:2.0.0.123-abc1234-rc
# - CD auto-deploys to qa environment
# - QA team can start testing

# 4. If bugs found, fix in release branch
git checkout release/v2.0.0
# ... fix bugs ...
git commit -m "Fix validation bug"
git push origin release/v2.0.0

# CI/CD automatically re-deploys to qa with new -rc tag

# 5. When QA approves, merge to master
git checkout master
git pull origin master
git merge --no-ff release/v2.0.0
git tag v2.0.0
git push origin master --tags

# What happens:
# - CI builds image: backend:2.0.0.123-abc1234
# - CD waits for manual approval
# - After approval in GitHub Actions UI:
#   → Deploys to prod environment

# 6. Merge release back to develop
git checkout develop
git merge --no-ff release/v2.0.0
git push origin develop

# 7. Clean up release branch (optional)
git branch -d release/v2.0.0
git push origin --delete release/v2.0.0
```

**Timeline:**
- Create release branch → **QA environment** (auto, ~5 min)
- Fix bugs in release → **QA environment** (auto, ~5 min per fix)
- Merge to master → **Production** (manual approval required)

### 3. Hotfix for Production

**Scenario:** Critical bug in production needs immediate fix

```bash
# 1. Create hotfix branch from master
git checkout master
git pull origin master
git checkout -b hotfix/critical-bug

# 2. Fix the issue
# ... make fix ...
git commit -m "Fix critical production bug"
git push origin hotfix/critical-bug

# What happens:
# - CI builds image: backend:1.0.0.456-abc1234-hotfix-critical-bug
# - CD auto-deploys to dev environment for verification

# 3. Test in dev, then create PR to master
# After approval and merge to master:

git checkout master
git merge --no-ff hotfix/critical-bug
git tag v1.0.1
git push origin master --tags

# What happens:
# - CI builds image: backend:1.0.1.456-abc1234
# - CD waits for manual approval
# - Deploy to prod after approval

# 4. Merge hotfix to develop to keep the fix
git checkout develop
git merge --no-ff hotfix/critical-bug
git push origin develop

# 5. Clean up
git branch -d hotfix/critical-bug
git push origin --delete hotfix/critical-bug
```

## Manual Deployments

Sometimes you need to manually deploy a specific version:

```bash
# In GitHub Actions UI:
# 1. Go to Actions → Backend Service CD
# 2. Click "Run workflow"
# 3. Select:
#    - Environment: dev/qa/prod
#    - Version: 1.0.0.456-abc1234-dev
# 4. Click "Run workflow"
```

**Use cases:**
- Re-deploy a previous version (rollback)
- Deploy to prod after master merge
- Test a specific version in different environment

## Version Patterns Quick Reference

| Branch | Example Version | Deploy To |
|--------|-----------------|-----------|
| develop | `1.0.0.456-abc1234-dev` | dev (auto) |
| release/v2.0 | `1.0.0.456-abc1234-rc` | qa (auto) |
| master | `1.0.0.456-abc1234` | prod (manual) |
| feature/api | `1.0.0.456-abc1234-feature-api` | none |
| hotfix/bug | `1.0.0.456-abc1234-hotfix-bug` | dev (auto) |

## GitHub Branch Protection

The repository has the following protections enabled:

### `develop` Branch
- ✅ Requires pull request before merging
- ✅ Requires 1 approval
- ✅ Requires CI to pass
- ❌ Cannot force push
- ❌ Cannot delete

### `release/*` Branches
- ✅ Requires pull request to merge to master
- ✅ Requires 2 approvals
- ✅ Requires CI to pass
- ❌ Cannot force push

### `master` Branch
- ✅ Requires pull request before merging
- ✅ Requires 2 approvals
- ✅ Requires review from code owners
- ✅ Requires CI to pass
- ✅ Requires production approval for deployment
- ❌ Cannot force push
- ❌ Cannot delete

## Deployment Approvals

Deployments require approval based on environment:

| Environment | Approval Required | Reviewers |
|-------------|-------------------|-----------|
| **dev** | ❌ No | Automatic |
| **qa** | ⚠️  Optional | QA Team |
| **prod** | ✅ Yes | DevOps + Team Lead |

Production deployments have a **30-minute cooling period** before deployment can proceed (configurable in GitHub environment settings).

## Monitoring Deployments

### Check What's Deployed

```bash
# View deployed version in dev
kubectl get deployment backend -n backend-services \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# View deployed version in qa
kubectl get deployment backend -n backend-services \
  --context qa-cluster \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# View deployed version in prod
kubectl get deployment backend -n backend-services \
  --context prod-cluster \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### View Deployment History

```bash
# In GitHub:
# - Go to Actions → Backend Service CD
# - View recent workflow runs
# - Each run shows: branch, version, environment, status

# Check deployment rollout status:
kubectl rollout status deployment/backend -n backend-services

# View deployment history:
kubectl rollout history deployment/backend -n backend-services
```

## Troubleshooting

### My feature branch didn't deploy

**This is expected!** Feature branches only build and test - they don't deploy.

**Solution:** Merge your feature branch to `develop` to deploy to dev environment.

### develop merged but didn't deploy to dev

**Check:**
1. Did CI workflow succeed? (Check Actions tab)
2. Did CD workflow trigger? (Check Actions → Backend Service CD)
3. Are there any failed jobs in the CD workflow?

**Common causes:**
- CI build failed (fix and push again)
- AWS credentials expired (check secrets)
- EKS cluster not accessible (verify cluster exists)

### release branch deployed to dev instead of qa

**This shouldn't happen with the branch-based workflow.**

**Check:**
- Verify branch name starts with `release/` (e.g., `release/v2.0.0`)
- Check CI workflow logs for environment determination
- Verify CD workflow received correct metadata

### Production deployment stuck waiting for approval

**This is expected!** Production deployments require manual approval.

**Solution:**
1. Go to Actions → Backend Service CD → Find the workflow run
2. Click on the "deploy" job
3. Click "Review deployments"
4. Select "prod" environment
5. Click "Approve and deploy"

Or use manual deployment via workflow_dispatch.

### Wrong version deployed

**Rollback procedure:**
```bash
# 1. Find the correct version tag:
git tag --sort=-creatordate | head -5

# 2. Manually trigger deployment with correct version:
# Go to Actions → Backend Service CD → Run workflow
# Select environment and enter the correct version tag
```

### Need to deploy same code to multiple environments

```bash
# Scenario: Testing in qa, want same version in dev

# 1. Find the version from qa:
kubectl get deployment backend -n backend-services --context qa-cluster \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# Example output: 123456789.dkr.ecr.us-east-1.amazonaws.com/backend:1.0.0.456-abc1234-rc

# 2. Manually deploy that version to dev:
# Actions → Backend Service CD → Run workflow
# Environment: dev
# Version: 1.0.0.456-abc1234-rc
```

## Best Practices

### 1. Keep develop stable
- Only merge working features to develop
- develop should always be deployable
- If develop breaks, fix immediately

### 2. Release branches are for stabilization
- No new features in release branches
- Only bug fixes and adjustments
- Keep changes minimal

### 3. Test in qa before production
- Always create release branch and test in qa
- Don't merge directly to master from develop
- QA approval required before prod merge

### 4. Hotfixes are urgent only
- Use hotfix branches only for critical production issues
- For normal bugs, use feature branches

### 5. Clean up old branches
- Delete feature branches after merge
- Delete release branches after prod deployment
- Keep branch list clean

### 6. Meaningful commit messages
```bash
# Good:
git commit -m "Add user authentication API endpoint"
git commit -m "Fix validation error in payment flow"

# Bad:
git commit -m "Update"
git commit -m "Fix bug"
```

### 7. Tag production releases
```bash
# Always tag master merges:
git tag v1.2.0
git push origin v1.2.0

# Tag format: v{major}.{minor}.{patch}
```

## Quick Reference Card

```
┌─────────────────────────────────────────────────────────────┐
│  BRANCH → ENVIRONMENT QUICK REFERENCE                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  feature/xxx  →  Build/Test Only  →  No Deploy            │
│       ↓ PR                                                  │
│                                                             │
│  develop      →  CI Builds        →  Auto-Deploy to dev    │
│       ↓ branch                                              │
│                                                             │
│  release/vX   →  CI Builds        →  Auto-Deploy to qa     │
│       ↓ PR (after QA approval)                              │
│                                                             │
│  master       →  CI Builds        →  Manual Deploy to prod │
│                                                             │
│  hotfix/xxx   →  CI Builds        →  Auto-Deploy to dev    │
│       ↓ PR (urgent)                    (test then prod)     │
│  master       →  CI Builds        →  Manual Deploy to prod │
│                                                             │
└─────────────────────────────────────────────────────────────┘

DEPLOYMENT TIMES:
  • dev:  ~5 minutes (automatic)
  • qa:   ~5 minutes (automatic)
  • prod: ~10 minutes (manual approval + 30min cooling)

APPROVAL REQUIREMENTS:
  • dev:  None (automatic)
  • qa:   Optional (QA team)
  • prod: Required (DevOps + Team Lead, 2 approvers)
```

## Summary

This workflow provides:
- ✅ **Fast feedback** - develop → dev in 5 minutes
- ✅ **Safe releases** - qa testing before production
- ✅ **Controlled production** - manual approvals required
- ✅ **Clear process** - branch name = environment
- ✅ **Team coordination** - protected branches prevent mistakes
- ✅ **Audit trail** - all deployments tracked in Actions

For implementation details or troubleshooting, check the [Architecture Documentation](ARCHITECTURE.md) or contact the DevOps team.

# Git Workflow Strategy - Branch-Based Deployments

## Overview

This document outlines the Git branching strategy and how branches map to deployment environments.

## Branch Strategy

```
master/main          → Production      (manual approval required)
release/*            → QA              (auto-deploy for testing)
develop              → Dev             (auto-deploy for fast feedback)
feature/*            → Build only      (no deployment, PR to develop)
hotfix/*             → Build + Dev     (urgent fixes, PR to master + develop)
```

## Branch-to-Environment Mapping

| Branch Pattern | Environment | Auto-Deploy | Version Pattern | Purpose |
|----------------|-------------|-------------|-----------------|---------|
| `develop` | dev | ✅ Yes | `1.0.0.123-abc1234-dev` | Active development, fast feedback |
| `release/v*` | qa | ✅ Yes | `1.0.0.123-abc1234-rc1` | Release candidates for testing |
| `master`/`main` | prod | ❌ No (manual) | `1.0.0.123-abc1234` | Production releases |
| `feature/*` | none | ❌ No | `1.0.0.123-abc1234-feature` | Build/test only, no deploy |
| `hotfix/*` | dev | ⚠️ Optional | `1.0.0.123-abc1234-hotfix` | Urgent fixes |

## Workflow Lifecycle

### Feature Development Flow
```
1. Create feature branch from develop
   git checkout -b feature/add-user-api develop

2. Develop and commit changes
   git commit -m "Add user API endpoint"

3. Push and create PR to develop
   git push origin feature/add-user-api

4. CI runs: build, test, security scan (no deploy)

5. After PR approval and merge to develop:
   - CI builds and pushes image with -dev suffix
   - CD auto-deploys to dev environment
   - Developers can test immediately
```

### Release Flow
```
1. Create release branch from develop
   git checkout -b release/v1.2.0 develop

2. Bump version in pom.xml
   <version>1.2.0</version>

3. Push release branch
   git push origin release/v1.2.0

4. CI builds and pushes image with -rc suffix
   - CD auto-deploys to qa environment
   - QA team tests the release candidate

5. If bugs found:
   - Fix in release branch
   - CI/CD re-deploys to qa
   - Repeat testing

6. When ready for production:
   - Merge release branch to master
   - Tag master with version: v1.2.0
   - Manual approval required for prod deployment
   - Merge release branch back to develop
```

### Hotfix Flow
```
1. Create hotfix branch from master
   git checkout -b hotfix/critical-bug master

2. Fix the issue and test

3. Merge to master (with approval)
   - Tag with version
   - Deploy to prod (manual)

4. Merge to develop (to keep fix in future releases)
```

## Version Tagging Strategy

Version tags are generated automatically based on branch:

### Develop Branch
```bash
# Format: {base_version}.{build_number}-{short_sha}-dev
# Example: 1.0.0.456-abc1234-dev

BASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout | sed 's/-SNAPSHOT$//')
BUILD_NUM=${{ github.run_number }}
SHORT_SHA=${GITHUB_SHA::8}
VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-dev"
```

### Release Branch
```bash
# Format: {base_version}.{build_number}-{short_sha}-rc{rc_number}
# Example: 1.0.0.456-abc1234-rc1

RELEASE_VERSION=$(echo "${GITHUB_REF}" | sed 's|refs/heads/release/v||')
VERSION="${RELEASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-rc1"
```

### Master Branch
```bash
# Format: {base_version}.{build_number}-{short_sha}
# Example: 1.0.0.456-abc1234

VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}"
```

### Feature Branch
```bash
# Format: {base_version}.{build_number}-{short_sha}-feature-{name}
# Example: 1.0.0.456-abc1234-feature-user-api

FEATURE_NAME=$(echo "${GITHUB_REF}" | sed 's|refs/heads/feature/||' | sed 's|/|-|g')
VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-feature-${FEATURE_NAME}"
```

## Workflow Changes Required

### 1. Update CI Workflow Triggers

**File:** `.github/workflows/service-backend-ci.yml`

```yaml
on:
  push:
    branches:
      - master
      - main
      - develop
      - 'release/**'
      - 'feature/**'
      - 'hotfix/**'
    paths:
      - 'backend/**'
      - 'sre/helm/backend/**'
      - '.github/workflows/service-backend-ci.yml'

  pull_request:
    branches:
      - master
      - main
      - develop
    paths:
      - 'backend/**'
      - 'sre/helm/backend/**'
      - '.github/workflows/service-backend-ci.yml'
```

### 2. Update Version Generation Logic

Add environment detection based on branch:

```yaml
- name: Determine environment and version
  id: version
  working-directory: ./backend
  run: |
    BASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout | sed 's/-SNAPSHOT$//')
    BUILD_NUM=${{ github.run_number }}
    SHORT_SHA=${GITHUB_SHA::8}
    BRANCH_NAME="${GITHUB_REF#refs/heads/}"

    # Determine environment and version suffix based on branch
    if [[ "$BRANCH_NAME" == "develop" ]]; then
      ENV="dev"
      VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-dev"
      SHOULD_DEPLOY="true"

    elif [[ "$BRANCH_NAME" =~ ^release/ ]]; then
      ENV="qa"
      RELEASE_VERSION=$(echo "$BRANCH_NAME" | sed 's|release/v||')
      VERSION="${RELEASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-rc1"
      SHOULD_DEPLOY="true"

    elif [[ "$BRANCH_NAME" == "master" ]] || [[ "$BRANCH_NAME" == "main" ]]; then
      ENV="prod"
      VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}"
      SHOULD_DEPLOY="false"  # Requires manual approval

    elif [[ "$BRANCH_NAME" =~ ^feature/ ]]; then
      ENV="none"
      FEATURE_NAME=$(echo "$BRANCH_NAME" | sed 's|feature/||' | sed 's|/|-|g')
      VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-feature-${FEATURE_NAME}"
      SHOULD_DEPLOY="false"

    elif [[ "$BRANCH_NAME" =~ ^hotfix/ ]]; then
      ENV="dev"  # Deploy hotfixes to dev for testing
      HOTFIX_NAME=$(echo "$BRANCH_NAME" | sed 's|hotfix/||' | sed 's|/|-|g')
      VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-hotfix-${HOTFIX_NAME}"
      SHOULD_DEPLOY="true"

    else
      ENV="none"
      VERSION="${BASE_VERSION}.${BUILD_NUM}-${SHORT_SHA}-${BRANCH_NAME}"
      SHOULD_DEPLOY="false"
    fi

    echo "version=${VERSION}" >> $GITHUB_OUTPUT
    echo "environment=${ENV}" >> $GITHUB_OUTPUT
    echo "should-deploy=${SHOULD_DEPLOY}" >> $GITHUB_OUTPUT
    echo "branch=${BRANCH_NAME}" >> $GITHUB_OUTPUT

    echo "📦 Version: ${VERSION}"
    echo "🎯 Environment: ${ENV}"
    echo "🚀 Should Deploy: ${SHOULD_DEPLOY}"
```

### 3. Update CD Workflow Triggers

**File:** `.github/workflows/service-backend-cd.yml`

```yaml
on:
  workflow_run:
    workflows: ["Backend Service CI"]
    types: [completed]
    branches:
      - main
      - master
      - develop
      - 'release/**'
      - 'hotfix/**'
```

### 4. Update CD Environment Determination

Replace version-pattern-based logic with branch-based logic:

```yaml
- name: Determine deployment target
  id: determine
  run: |
    if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
      # Manual dispatch - use inputs
      ENV="${{ inputs.environment }}"
      VERSION="${{ inputs.version }}"
      SHOULD_DEPLOY="true"
    else
      # Automatic from CI - get metadata from artifact
      VERSION=$(cat build-metadata/version.txt)
      IMAGE_REF=$(cat build-metadata/image-ref.txt)
      BRANCH_NAME=$(cat build-metadata/branch.txt)  # Add branch to metadata

      # Determine environment based on branch name
      if [[ "$BRANCH_NAME" == "develop" ]]; then
        ENV="dev"
        SHOULD_DEPLOY="true"

      elif [[ "$BRANCH_NAME" =~ ^release/ ]]; then
        ENV="qa"
        SHOULD_DEPLOY="true"

      elif [[ "$BRANCH_NAME" == "master" ]] || [[ "$BRANCH_NAME" == "main" ]]; then
        ENV="prod"
        SHOULD_DEPLOY="false"  # Requires manual approval
        echo "⚠️  Production deployment requires manual approval"
        echo "Run workflow_dispatch with environment=prod and version=${VERSION}"

      elif [[ "$BRANCH_NAME" =~ ^hotfix/ ]]; then
        ENV="dev"
        SHOULD_DEPLOY="true"

      else
        ENV="none"
        SHOULD_DEPLOY="false"
        echo "⚠️  Branch ${BRANCH_NAME} does not trigger automatic deployment"
      fi
    fi

    # For manual dispatch, construct image-ref
    if [[ "${{ github.event_name }}" == "workflow_dispatch" ]]; then
      IMAGE_REF="${{ secrets.AWS_${{ inputs.environment }}_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com/backend:${VERSION}"
    fi

    echo "environment=${ENV}" >> $GITHUB_OUTPUT
    echo "version=${VERSION}" >> $GITHUB_OUTPUT
    echo "should-deploy=${SHOULD_DEPLOY}" >> $GITHUB_OUTPUT
    echo "image-ref=${IMAGE_REF}" >> $GITHUB_OUTPUT
```

### 5. Save Branch Name in CI Metadata

Update CI workflow to save branch information:

```yaml
- name: Save build metadata for CD
  run: |
    mkdir -p build-metadata
    echo "${{ steps.version.outputs.version }}" > build-metadata/version.txt
    echo "${{ steps.docker.outputs.image-ref }}" > build-metadata/image-ref.txt
    echo "${{ steps.version.outputs.environment }}" > build-metadata/environment.txt
    echo "${{ steps.version.outputs.branch }}" > build-metadata/branch.txt
    echo "${{ steps.version.outputs.should-deploy }}" > build-metadata/should-deploy.txt
```

## Branch Protection Rules

Configure in GitHub Settings → Branches:

### `develop` Branch
```yaml
Protection Rules:
  ✅ Require pull request before merging
  ✅ Require approvals: 1
  ✅ Require status checks to pass: CI/build-and-test
  ✅ Require conversation resolution
  ❌ Do not allow force pushes
  ❌ Do not allow deletions
```

### `release/*` Branches
```yaml
Protection Rules:
  ✅ Require pull request before merging (to master)
  ✅ Require approvals: 2
  ✅ Require status checks to pass: CI/build-and-test
  ✅ Require conversation resolution
  ❌ Do not allow force pushes
  ❌ Do not allow deletions
```

### `master`/`main` Branch
```yaml
Protection Rules:
  ✅ Require pull request before merging
  ✅ Require approvals: 2
  ✅ Require review from Code Owners
  ✅ Require status checks to pass: CI/build-and-test
  ✅ Require conversation resolution
  ✅ Require branches to be up to date
  ✅ Require deployments to succeed: production (with approval)
  ❌ Do not allow force pushes
  ❌ Do not allow deletions
```

## GitHub Environments Configuration

Configure in GitHub Settings → Environments:

### Development Environment
```yaml
Environment Name: dev
Protection Rules:
  ❌ No approval required
  ⏱️  Wait timer: 0 minutes
  🔒 Deployment branches: develop, hotfix/*
Environment Secrets:
  - AWS_DEV_ACCOUNT_ID
  - AWS_DEV_ROLE_ARN
```

### QA Environment
```yaml
Environment Name: qa
Protection Rules:
  ✅ Required reviewers: QA team (1 reviewer)
  ⏱️  Wait timer: 0 minutes
  🔒 Deployment branches: release/*
Environment Secrets:
  - AWS_QA_ACCOUNT_ID
  - AWS_QA_ROLE_ARN
```

### Production Environment
```yaml
Environment Name: prod
Protection Rules:
  ✅ Required reviewers: DevOps + Team Lead (2 reviewers)
  ⏱️  Wait timer: 30 minutes (cooling period)
  🔒 Deployment branches: master, main
Environment Secrets:
  - AWS_PROD_ACCOUNT_ID
  - AWS_PROD_ROLE_ARN
```

## Initial Setup Steps

### Step 1: Create `develop` Branch

```bash
# From your current master branch
git checkout master
git pull origin master

# Create develop branch
git checkout -b develop
git push -u origin develop

# Set develop as default branch in GitHub (optional)
# Settings → Branches → Default branch → develop
```

### Step 2: Update pom.xml Version

```xml
<!-- backend/pom.xml -->
<version>1.0.0-SNAPSHOT</version>
```

### Step 3: Create Branch Protection Rules

Follow the branch protection rules outlined above in GitHub Settings.

### Step 4: Update Workflows

Apply the workflow changes from this document to:
- `.github/workflows/service-backend-ci.yml`
- `.github/workflows/service-backend-cd.yml`

### Step 5: Test the Flow

```bash
# Test feature → develop flow
git checkout -b feature/test-workflow develop
echo "test" >> test.txt
git add test.txt
git commit -m "Test workflow"
git push origin feature/test-workflow

# Create PR to develop in GitHub
# Verify CI runs build/test but doesn't deploy
# Merge PR
# Verify CD auto-deploys to dev
```

## Benefits of This Approach

### 1. **Clear Environment Mapping**
- No ambiguity: branch name directly determines environment
- Easy to understand for all team members
- No need to remember version pattern conventions

### 2. **Fast Development Feedback**
- Develop → dev: Immediate deployment after merge
- Developers see changes in minutes

### 3. **Safe Release Process**
- Release branches isolated for QA testing
- Multiple QA cycles possible before prod
- No risk of ongoing dev work affecting release

### 4. **Production Safety**
- Master deployments require manual approval
- Protection rules prevent accidental merges
- Environment approvals add extra safety layer

### 5. **Flexible Hotfix Process**
- Hotfix branches can deploy to dev for testing
- Then merge directly to master when validated
- Can skip full release cycle for urgent fixes

## Comparison with Current Version-Based Approach

| Aspect | Current (Version Pattern) | Proposed (Branch-Based) |
|--------|---------------------------|-------------------------|
| **Clarity** | Must remember: SNAPSHOT=dev, RC=qa | Branch name = environment |
| **Mistakes** | Easy to use wrong version suffix | Branch protection prevents mistakes |
| **Feature Branches** | Not clear how to version | Clear: feature/* = no deploy |
| **Releases** | Must manually create RC versions | Release branch auto-tags as RC |
| **Hotfixes** | Unclear process | Defined hotfix/* flow |
| **Team Understanding** | Requires documentation | Self-explanatory |

## Common Workflows

### Scenario 1: New Feature

```bash
# Developer creates feature branch from develop
git checkout -b feature/user-profile develop

# Work on feature, push commits
git push origin feature/user-profile

# CI runs on each push: build, test, scan (no deploy)

# Create PR to develop
# After review and merge:
#   → CI builds with -dev tag
#   → CD deploys to dev automatically
#   → Feature available in dev for testing
```

### Scenario 2: Preparing a Release

```bash
# Release manager creates release branch
git checkout -b release/v2.0.0 develop
git push origin release/v2.0.0

# CI builds with -rc1 tag
# CD deploys to qa automatically
# QA team tests in qa environment

# If bugs found, fix in release branch:
git commit -m "Fix bug in release"
git push origin release/v2.0.0

# CI/CD re-deploys to qa with -rc2 tag
# QA tests again

# When ready for production:
git checkout master
git merge --no-ff release/v2.0.0
git tag v2.0.0
git push origin master --tags

# Manual approval required in GitHub Actions
# After approval, CD deploys to prod

# Merge release back to develop
git checkout develop
git merge --no-ff release/v2.0.0
git push origin develop
```

### Scenario 3: Urgent Production Hotfix

```bash
# Create hotfix from master
git checkout -b hotfix/critical-bug master

# Fix the issue
git commit -m "Fix critical production bug"
git push origin hotfix/critical-bug

# CI builds and deploys to dev for verification
# Test in dev environment

# When validated, create PR to master
# After approval and merge:
#   → Manual deployment to prod (with approval)

# Also merge to develop to keep fix:
git checkout develop
git merge --no-ff hotfix/critical-bug
git push origin develop
```

## Monitoring and Observability

### GitHub Actions Logs
- Monitor workflow runs per branch
- Track deployment frequency per environment
- Alert on failed deployments

### Environment Status
```bash
# Check what's deployed in each environment
aws ecr describe-images \
  --repository-name backend \
  --query 'sort_by(imageDetails,& imagePushedAt)[-5:].[imageTags[0],imagePushedAt]' \
  --output table
```

### Version Tracking
```bash
# In dev environment
kubectl get deployment backend -n backend-services -o jsonpath='{.spec.template.spec.containers[0].image}'

# In qa environment
kubectl get deployment backend -n backend-services -o jsonpath='{.spec.template.spec.containers[0].image}'

# In prod environment
kubectl get deployment backend -n backend-services -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Troubleshooting

### Issue: Deployment not triggered after merge to develop

**Check:**
1. Verify workflow triggers include develop branch
2. Check if path filters exclude your changes
3. Verify CI workflow completed successfully
4. Check CD workflow logs for environment determination

### Issue: Wrong environment deployed

**Check:**
1. Verify branch name matches expected pattern
2. Check build-metadata/branch.txt in artifacts
3. Verify environment determination logic in CD workflow

### Issue: Production deployment fails

**Check:**
1. Verify manual approval was granted
2. Check AWS PROD credentials are configured
3. Verify prod EKS cluster is accessible
4. Check Helm chart values for prod environment

## Migration Plan

To migrate from current setup to branch-based workflow:

### Phase 1: Preparation (1 hour)
1. Create develop branch from master
2. Update branch protection rules
3. Configure GitHub environments
4. Update documentation

### Phase 2: Workflow Updates (2 hours)
1. Update CI workflow with new branching triggers
2. Update version generation logic
3. Update CD workflow with branch-based determination
4. Add branch name to build metadata

### Phase 3: Testing (1 hour)
1. Test feature branch: build only
2. Test develop branch: auto-deploy to dev
3. Test release branch: auto-deploy to qa
4. Test master merge: manual prod approval

### Phase 4: Team Onboarding (1 hour)
1. Present new workflow to team
2. Update team documentation
3. Practice creating feature branches
4. Practice release process

**Total Time: ~5 hours**

## Summary

This branch-based workflow provides:
- ✅ Clear, intuitive branch-to-environment mapping
- ✅ Fast development feedback (develop → dev)
- ✅ Safe release testing (release/* → qa)
- ✅ Protected production (master → prod with approval)
- ✅ Defined processes for features, releases, and hotfixes
- ✅ GitHub native protections and approvals
- ✅ Audit trail of all deployments

The workflow is industry-standard, easy to understand, and provides the right balance of automation and safety.

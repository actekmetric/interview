# ECR Provision and Push Action

A reusable composite GitHub Action that provisions AWS ECR repositories using Terragrunt and pushes Docker images to them.

## Overview

This action combines infrastructure provisioning and image deployment into a single step:

1. **Provisions ECR Repository** - Uses Terragrunt to create/update ECR repo with lifecycle policies
2. **Checks for Changes** - Runs `terragrunt plan` and only applies if changes detected
3. **Pushes Docker Image** - Tags and pushes image to ECR with semantic versioning
4. **Triggers Scan** - Initiates ECR vulnerability scan

## Features

- ✅ **Infrastructure as Code** - ECR managed via Terraform/Terragrunt
- ✅ **Idempotent** - Only applies changes when needed
- ✅ **Dynamic Configuration** - Each microservice can specify its own settings
- ✅ **Multi-environment** - Works with dev, qa, prod
- ✅ **Lifecycle Policies** - Automatic image retention management
- ✅ **Security** - Encryption, scanning, OIDC authentication

## Usage

### Basic Example

```yaml
- name: Provision ECR and Push Image
  uses: ./.github/actions/ecr-provision-and-push
  with:
    repository-name: backend
    environment: dev
    image-ref: ghcr.io/actekmetric/backend:1.0.123-abc12345
    image-tag: 1.0.123-abc12345-SNAPSHOT
```

### Full Example with All Options

```yaml
- name: Provision ECR and Push Image
  id: ecr-push
  uses: ./.github/actions/ecr-provision-and-push
  with:
    repository-name: backend
    environment: dev
    image-ref: ghcr.io/actekmetric/backend:1.0.123-abc12345
    image-tag: 1.0.123-abc12345-SNAPSHOT
    aws-region: us-east-1
    max-image-count: 10
    untagged-expire-days: 7
    image-tag-mutability: MUTABLE
    terragrunt-version: v0.55.1
    terraform-version: 1.6.0

- name: Use outputs
  run: |
    echo "ECR URL: ${{ steps.ecr-push.outputs.ecr-repository-url }}"
    echo "Image URI: ${{ steps.ecr-push.outputs.ecr-image-uri }}"
    echo "Changes Made: ${{ steps.ecr-push.outputs.terragrunt-changes }}"
```

### Environment-Specific Settings

```yaml
strategy:
  matrix:
    environment: [dev, qa, prod]

steps:
  - name: Provision ECR and Push Image
    uses: ./.github/actions/ecr-provision-and-push
    with:
      repository-name: backend
      environment: ${{ matrix.environment }}
      image-ref: ${{ needs.build.outputs.image-ref }}
      image-tag: ${{ needs.build.outputs.version }}
      # Production gets stricter settings
      max-image-count: ${{ matrix.environment == 'prod' && '20' || '10' }}
      untagged-expire-days: ${{ matrix.environment == 'prod' && '3' || '7' }}
      image-tag-mutability: ${{ matrix.environment == 'prod' && 'IMMUTABLE' || 'MUTABLE' }}
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `repository-name` | ECR repository name (e.g., backend, frontend) | ✅ Yes | - |
| `environment` | Environment (dev, qa, prod) | ✅ Yes | - |
| `image-ref` | Full Docker image reference to push | ✅ Yes | - |
| `image-tag` | Semantic version tag for the image | ✅ Yes | - |
| `aws-region` | AWS region | No | `us-east-1` |
| `max-image-count` | Maximum number of tagged images to keep | No | `10` |
| `untagged-expire-days` | Days before untagged images expire | No | `7` |
| `image-tag-mutability` | Image tag mutability (MUTABLE or IMMUTABLE) | No | `MUTABLE` |
| `terragrunt-version` | Terragrunt version | No | `v0.55.1` |
| `terraform-version` | Terraform version | No | `1.6.0` |

## Outputs

| Output | Description | Example |
|--------|-------------|---------|
| `ecr-repository-url` | Full ECR repository URL | `596308305263.dkr.ecr.us-east-1.amazonaws.com/backend` |
| `ecr-image-uri` | Full ECR image URI with tag | `596308305263.dkr.ecr.us-east-1.amazonaws.com/backend:1.0.123-abc12345` |
| `terragrunt-changes` | Whether Terragrunt made changes | `true` or `false` |

## How It Works

### 1. Validate Inputs

```bash
environment must be: dev, qa, prod
image-tag-mutability must be: MUTABLE, IMMUTABLE
```

### 2. Setup Tools

- Installs Terraform (specified version)
- Installs Terragrunt (specified version)

### 3. Create Dynamic Terragrunt Config

Creates a temporary Terragrunt configuration at:
```
sre/terragrunt/environments/{environment}/ecr-dynamic/terragrunt.hcl
```

With the repository-specific settings from inputs.

### 4. Run Terragrunt Plan

```bash
terragrunt plan -out=tfplan -detailed-exitcode
```

**Exit codes:**
- `0` - No changes needed (skip apply)
- `2` - Changes present (run apply)
- `1` - Error (fail workflow)

### 5. Run Terragrunt Apply (if needed)

```bash
terragrunt apply tfplan
```

Only runs if plan detected changes.

### 6. Push Docker Image to ECR

- Logs in to ECR
- Pulls image from source registry (GHCR)
- Tags with semantic version: `{image-tag}`
- Tags with environment-latest: `{environment}-latest`
- Pushes both tags to ECR

### 7. Trigger Vulnerability Scan

```bash
aws ecr start-image-scan --repository-name {repo} --image-id imageTag={tag}
```

### 8. Cleanup

Removes the temporary dynamic Terragrunt config.

## Image Tagging Strategy

Each push creates **two tags**:

### 1. Semantic Version Tag
```
Format: {maven.version}.{build.number}-{git.sha}-SNAPSHOT
Example: 1.0.123-abc12345-SNAPSHOT
```

**Use for:**
- Specific deployments
- Rollbacks
- Auditing

### 2. Environment Latest Tag
```
Format: {environment}-latest
Examples: dev-latest, qa-latest, prod-latest
```

**Use for:**
- Quick testing
- Default deployments
- Auto-updating dev environments

## ECR Repository Configuration

The action creates ECR repositories with:

### Security
- ✅ AES256 encryption at rest
- ✅ Vulnerability scanning on push
- ✅ Repository policies for GitHub Actions OIDC

### Lifecycle Policies

**Tagged Images:**
- Keeps last N images (configurable via `max-image-count`)
- Only expires versioned tags (v*, 0-9*)

**Untagged Images:**
- Expires after N days (configurable via `untagged-expire-days`)
- Cleans up intermediate layers

### Tags

All repositories are tagged with:
```yaml
Environment: dev/qa/prod
ManagedBy: GitHub-Actions
Component: ECR
Service: {repository-name}
region: us-east-1
```

## Prerequisites

### GitHub Secrets Required

```yaml
AWS_DEV_ACCOUNT_ID: "596308305263"
AWS_DEV_ROLE_ARN: "arn:aws:iam::596308305263:role/GitHubActionsRole-dev"

AWS_QA_ACCOUNT_ID: "234567890123"
AWS_QA_ROLE_ARN: "arn:aws:iam::234567890123:role/GitHubActionsRole-qa"

AWS_PROD_ACCOUNT_ID: "345678901234"
AWS_PROD_ROLE_ARN: "arn:aws:iam::345678901234:role/GitHubActionsRole-prod"
```

### Workflow Permissions

```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read   # Required to checkout code
```

### AWS IAM Permissions

The GitHub Actions OIDC role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DescribeRepositories",
        "ecr:PutLifecyclePolicy",
        "ecr:SetRepositoryPolicy",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:StartImageScan",
        "ecr:DescribeImages",
        "ecr:ListImages",
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "*"
    }
  ]
}
```

## Example Workflow

Complete example from `service-backend-workflow.yml`:

```yaml
name: Backend Service CI/CD

on:
  push:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      image-ref: ${{ steps.docker.outputs.image-ref }}
    steps:
      # Build, test, scan, push to GHCR
      # ...

  push-to-ecr:
    name: Push to AWS ECR
    runs-on: ubuntu-latest
    needs: build-and-test
    permissions:
      id-token: write
      contents: read
    strategy:
      matrix:
        environment: [dev, qa, prod]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: ./.github/actions/aws-assume-role
        with:
          role-to-assume: ${{ secrets[format('AWS_{0}_ROLE_ARN', upper(matrix.environment))] }}
          aws-region: us-east-1

      - name: Login to GHCR
        run: |
          echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin

      - name: Provision ECR and Push Image
        uses: ./.github/actions/ecr-provision-and-push
        with:
          repository-name: backend
          environment: ${{ matrix.environment }}
          image-ref: ${{ needs.build-and-test.outputs.image-ref }}
          image-tag: ${{ needs.build-and-test.outputs.version }}
          max-image-count: ${{ matrix.environment == 'prod' && '20' || '10' }}
          image-tag-mutability: ${{ matrix.environment == 'prod' && 'IMMUTABLE' || 'MUTABLE' }}
```

## Troubleshooting

### Error: Repository already exists

This is expected! The action will:
1. Detect existing repository
2. Run plan to check for config drift
3. Only apply if settings changed

### Error: Terragrunt plan failed

Check:
- AWS credentials are valid
- S3 bucket for state exists
- DynamoDB table for locks exists
- IAM permissions include Terraform state access

### Error: Docker login failed

Check:
- AWS credentials are valid
- ECR permissions include `ecr:GetAuthorizationToken`
- Region is correct

### Error: Image push failed

Check:
- Image was pulled successfully from source registry
- ECR repository exists (should be created by action)
- Repository policy allows GitHub Actions role

## Performance

**First run (new repository):**
- Terragrunt plan: ~15 seconds
- Terragrunt apply: ~10 seconds
- Image push: ~30-60 seconds (depends on image size)
- **Total: ~1-2 minutes**

**Subsequent runs (no changes):**
- Terragrunt plan: ~10 seconds
- Terragrunt apply: **skipped**
- Image push: ~30-60 seconds
- **Total: ~45 seconds**

## Limitations

- Only supports ECR in a single region per invocation
- Requires Terraform state backend (S3 + DynamoDB)
- Cannot manage cross-region replication (use AWS native replication)

## Future Enhancements

Potential improvements:
- [ ] Support for cross-region replication
- [ ] Custom scan on push webhooks
- [ ] Image signing with Cosign
- [ ] Automated security alerts on scan findings
- [ ] Cost reporting per repository

## Related Actions

- [aws-assume-role](../aws-assume-role/) - AWS OIDC authentication
- [docker-build-push](../docker-build-push/) - Build and push Docker images
- [trivy-scan](../trivy-scan/) - Security vulnerability scanning

## Contributing

When modifying this action:

1. Update version in action.yaml
2. Test with all environments (dev, qa, prod)
3. Update this README
4. Update workflow examples in [.github/workflows/README.md](../../workflows/README.md)

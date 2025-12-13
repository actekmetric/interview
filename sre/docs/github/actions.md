# Reusable GitHub Actions

This directory contains custom composite actions for infrastructure and application CI/CD pipelines.

## Available Actions

### Infrastructure Actions

#### 1. 🔧 terraform-setup
Installs and configures Terraform and Terragrunt with intelligent caching.

**Key Features:**
- Installs specific versions of Terraform and Terragrunt
- Caches Terragrunt binaries to speed up workflows
- Verifies installations and outputs versions
- Generates step summary with tool versions

**Usage:**
```yaml
- name: Setup Terraform and Terragrunt
  uses: ./.github/actions/terraform-setup
  with:
    terraform-version: '1.6.0'
    terragrunt-version: '0.54.8'
```

#### 2. 🔐 aws-assume-role
Authenticates to AWS using OIDC and assumes environment-specific IAM roles.

**Key Features:**
- OIDC-based authentication (no long-lived credentials)
- Environment-specific role assumption (dev, qa, prod)
- Configurable AWS region
- Session name includes run ID and commit SHA for traceability
- Verifies AWS identity after assumption

**Usage:**
```yaml
- name: Assume AWS Role
  uses: ./.github/actions/aws-assume-role
  with:
    environment: dev
    role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
    account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}
    aws-region: us-east-1
```

#### 3. ⚖️ workload-scale
Scales Kubernetes workloads to zero or restores them to saved replica counts.

**Key Features:**
- Save current replica counts before scaling to zero
- Restore workloads to previous replica counts
- Useful for cost optimization in non-production environments
- Generates deployment status summary after restore

**Usage:**
```yaml
# Stop workloads
- name: Scale Down Workloads
  uses: ./.github/actions/workload-scale
  with:
    action: save
    environment: dev
    namespace: default

# Restore workloads
- name: Restore Workloads
  uses: ./.github/actions/workload-scale
  with:
    action: restore
    environment: dev
    namespace: default
```

### Application Actions

#### 4. 🐳 docker-build
Builds multi-platform Docker images locally without pushing to any registry.

**Key Features:**
- Multi-platform builds (amd64, arm64)
- GitHub Actions cache optimization
- Builds locally without registry credentials
- Suitable for PRs and validation workflows
- Build arguments support
- Flexible image loading for scanning

[View Documentation](./actions/docker-build.md)

#### 5. 📤 ecr-publish
Tags and pushes pre-built Docker images to Amazon ECR.

**Key Features:**
- Uses official AWS ECR Login action for authentication
- ECR authentication with automatic password masking
- Tags local images with ECR registry path
- Pushes images to ECR
- Outputs full image URI
- Works after docker-build action
- Supports multi-account registries

[View Documentation](./actions/ecr-publish.md)

#### 6. 🔒 trivy-scan
Scans Docker images for security vulnerabilities with configurable thresholds.

**Key Features:**
- Configurable severity filtering
- SARIF report generation for GitHub Security tab
- Flexible exit codes (fail or continue)
- Artifact upload for scan results
- Support for private registries

[View Documentation](./trivy-scan/README.md)

#### 7. 📦 helm-publish
Lints, validates, and publishes Helm charts to GitHub Pages using chart-releaser.

**Key Features:**
- Automatic chart linting and validation
- Publishing to GitHub Pages
- Version and appVersion update support
- Template validation with dry-run
- Chart dependency management

[View Documentation](./helm-publish/README.md)

#### 8. 🔄 helm-rollback
Automatically rolls back Helm releases when post-deployment validation fails.

**Key Features:**
- Checks release history before rollback
- Handles first deployment edge case (optional uninstall)
- Configurable timeout and wait options
- Pod readiness verification after rollback
- Detailed outputs and status reporting
- Integrates with smoke tests in CD workflows

**Usage:**
```yaml
- name: Rollback on Smoke Test Failure
  if: failure() && steps.smoke-tests.outcome == 'failure'
  uses: ./.github/actions/helm-rollback
  with:
    cluster-name: tekmetric-dev
    release-name: backend
    namespace: backend-services
    timeout: 5m
```

[View Documentation](./actions/helm-rollback.md)

## Usage Examples

### Application Pipeline (Backend Service)
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-ref: ${{ steps.docker.outputs.image-ref }}
      image-uri: ${{ steps.ecr.outputs.image-uri }}
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      # Build Docker image (always runs, even for PRs)
      - name: Build Docker Image
        id: docker
        uses: ./.github/actions/docker-build
        with:
          context: ./backend
          dockerfile: docker/Dockerfile
          image-name: backend
          image-tag: 1.0.0-build.123-abc1234
          platforms: ${{ github.event_name == 'pull_request' && 'linux/amd64' || 'linux/amd64,linux/arm64' }}
          load: ${{ github.event_name == 'pull_request' && 'true' || 'false' }}

      # Scan for vulnerabilities (always runs)
      - name: Scan Image
        uses: ./.github/actions/trivy-scan
        with:
          image-ref: ${{ steps.docker.outputs.image-ref }}
          severity: CRITICAL,HIGH
          exit-code: '0'

      # Configure AWS credentials (only for deployable branches)
      - name: Configure AWS credentials
        if: github.event_name == 'push'
        uses: ./.github/actions/aws-assume-role
        with:
          environment: dev
          role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
          account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}
          aws-region: us-east-1

      # Publish to ECR (only for deployable branches)
      - name: Publish to ECR
        id: ecr
        if: github.event_name == 'push'
        uses: ./.github/actions/ecr-publish
        with:
          ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
          image-name: backend
          source-tag: 1.0.0-build.123-abc1234
          target-tag: 1.0.0-build.123-abc1234

  publish:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # Publish Helm chart
      - name: Publish Chart
        uses: ./.github/actions/helm-publish
        with:
          chart-path: sre/helm/backend
          chart-version: 1.0.0
          app-version: 1.0.0-build.123
          token: ${{ secrets.GITHUB_TOKEN }}
```

### Infrastructure Pipeline (Terraform/Terragrunt)
```yaml
jobs:
  terraform-deploy:
    runs-on: ubuntu-latest
    environment: dev
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      # Setup Terraform and Terragrunt
      - name: Setup Infrastructure Tools
        uses: ./.github/actions/terraform-setup
        with:
          terraform-version: '1.6.0'
          terragrunt-version: '0.54.8'

      # Authenticate to AWS
      - name: Assume AWS Role
        uses: ./.github/actions/aws-assume-role
        with:
          environment: dev
          role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
          account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}

      # Deploy infrastructure
      - name: Terragrunt Apply
        run: |
          cd sre/terragrunt/environments/dev
          terragrunt run-all apply --terragrunt-non-interactive
```

### Cost Optimization (Stop/Start Environments)
```yaml
jobs:
  stop-environment:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Assume AWS Role
        uses: ./.github/actions/aws-assume-role
        with:
          environment: dev
          role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
          account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}

      - name: Get EKS credentials
        run: |
          aws eks update-kubeconfig \
            --name tekmetric-dev \
            --region us-east-1

      - name: Scale Down Workloads
        uses: ./.github/actions/workload-scale
        with:
          action: save
          environment: dev
          namespace: default
```

## Design Philosophy

These actions follow these principles:

1. **Parameterization** - All actions accept parameters for flexibility
2. **Reusability** - Can be used across multiple projects
3. **Observability** - Rich summaries and outputs
4. **Safety** - Validation and error handling built-in
5. **Simplicity** - Easy to understand and maintain

## Action Categories

### Infrastructure Management
- **terraform-setup**: Version-pinned tool installation with caching
- **aws-assume-role**: OIDC-based AWS authentication
- **workload-scale**: Kubernetes workload lifecycle management

### Application Delivery
- **docker-build**: Multi-platform container builds (local only, no push)
- **ecr-publish**: Publishing images to Amazon ECR
- **trivy-scan**: Security vulnerability scanning
- **helm-publish**: Chart publishing to S3
- **helm-rollback**: Automatic rollback on post-deployment validation failure

## Differences from Other Implementations

- **Terraform Setup**: Intelligent caching to avoid repeated downloads
- **AWS Authentication**: OIDC-based (no static credentials in workflows)
- **Workload Scaling**: Preserves replica state for environment restoration
- **Helm Publishing**: Uses S3 with helm-s3 plugin (not ChartMuseum or GitHub Pages)
- **Helm Rollback**: Automatic rollback on smoke test failure (not just Helm deployment failure)
- **Docker Builds**: Separated build and publish concerns for better CI/CD control
- **Security Scanning**: Configurable thresholds and reporting options
- **Architecture**: 8 focused actions organized by purpose (infrastructure vs application)

## Contributing

When modifying these actions:
1. Test changes thoroughly in a feature branch
2. Update documentation in action.yaml and README.md
3. Ensure backwards compatibility or document breaking changes
4. Follow the existing parameter naming conventions

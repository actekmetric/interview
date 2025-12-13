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

#### 4. 🐳 docker-build-push
Builds multi-platform Docker images and pushes to GitHub Container Registry.

**Key Features:**
- Multi-platform builds (amd64, arm64)
- GitHub Actions cache optimization
- Conditional push (useful for PRs)
- Flexible tagging strategy
- Build arguments support

[View Documentation](./docker-build-push/README.md)

#### 5. 🔒 trivy-scan
Scans Docker images for security vulnerabilities with configurable thresholds.

**Key Features:**
- Configurable severity filtering
- SARIF report generation for GitHub Security tab
- Flexible exit codes (fail or continue)
- Artifact upload for scan results
- Support for private registries

[View Documentation](./trivy-scan/README.md)

#### 6. 📦 helm-publish
Lints, validates, and publishes Helm charts to GitHub Pages using chart-releaser.

**Key Features:**
- Automatic chart linting and validation
- Publishing to GitHub Pages
- Version and appVersion update support
- Template validation with dry-run
- Chart dependency management

[View Documentation](./helm-publish/README.md)

## Usage Examples

### Application Pipeline (Backend Service)
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-ref: ${{ steps.docker.outputs.image-ref }}
    steps:
      - uses: actions/checkout@v4

      # Build and push Docker image
      - name: Build Docker Image
        id: docker
        uses: ./.github/actions/docker-build-push
        with:
          context: ./backend
          dockerfile: docker/Dockerfile
          image-name: ${{ github.repository_owner }}/backend
          image-tag: 1.0.0-build.123
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}

      # Scan for vulnerabilities
      - name: Scan Image
        uses: ./.github/actions/trivy-scan
        with:
          image-ref: ${{ steps.docker.outputs.image-ref }}
          severity: CRITICAL,HIGH
          exit-code: '0'

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
- **docker-build-push**: Multi-platform container builds
- **trivy-scan**: Security vulnerability scanning
- **helm-publish**: Chart publishing to GitHub Pages

## Differences from Other Implementations

- **Terraform Setup**: Intelligent caching to avoid repeated downloads
- **AWS Authentication**: OIDC-based (no static credentials in workflows)
- **Workload Scaling**: Preserves replica state for environment restoration
- **Helm Publishing**: Uses GitHub Pages (not ChartMuseum) for simpler infrastructure
- **Docker Builds**: Inline approach without complex metadata handling
- **Security Scanning**: Configurable thresholds and reporting options
- **Architecture**: 6 focused actions organized by purpose (infrastructure vs application)

## Contributing

When modifying these actions:
1. Test changes thoroughly in a feature branch
2. Update documentation in action.yaml and README.md
3. Ensure backwards compatibility or document breaking changes
4. Follow the existing parameter naming conventions

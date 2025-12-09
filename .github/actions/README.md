# Reusable GitHub Actions

This directory contains custom composite actions for the backend service CI/CD pipeline.

## Available Actions

### 1. 📦 helm-publish
Lints, validates, and publishes Helm charts to GitHub Pages using chart-releaser.

**Key Features:**
- Automatic chart linting and validation
- Publishing to GitHub Pages
- Version detection from Chart.yaml
- Template validation with dry-run

[View Documentation](./helm-publish/README.md)

### 2. 🐳 docker-build-push
Builds multi-platform Docker images and pushes to GitHub Container Registry.

**Key Features:**
- Multi-platform builds (amd64, arm64)
- GitHub Actions cache optimization
- Conditional push (useful for PRs)
- Flexible tagging strategy

[View Documentation](./docker-build-push/README.md)

### 3. 🔒 trivy-scan
Scans Docker images for security vulnerabilities with configurable thresholds.

**Key Features:**
- Configurable severity filtering
- SARIF report generation for GitHub Security tab
- Flexible exit codes (fail or continue)
- Artifact upload for scan results

[View Documentation](./trivy-scan/README.md)

## Usage Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      # Build and push Docker image
      - name: Build Docker Image
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
          image-ref: ghcr.io/${{ github.repository_owner }}/backend:1.0.0-build.123
          severity: CRITICAL,HIGH
          exit-code: '0'

      # Publish Helm chart
      - name: Publish Chart
        uses: ./.github/actions/helm-publish
        with:
          chart-path: sre/helm/backend
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Design Philosophy

These actions follow these principles:

1. **Parameterization** - All actions accept parameters for flexibility
2. **Reusability** - Can be used across multiple projects
3. **Observability** - Rich summaries and outputs
4. **Safety** - Validation and error handling built-in
5. **Simplicity** - Easy to understand and maintain

## Differences from Other Implementations

- **Helm Publishing**: Uses gh-pages (not ChartMuseum) for simpler infrastructure
- **Docker Builds**: Inline approach without complex metadata handling
- **Security Scanning**: Configurable thresholds and reporting options
- **Architecture**: 3 focused actions (not a microservices approach)

## Contributing

When modifying these actions:
1. Test changes thoroughly in a feature branch
2. Update documentation in action.yaml and README.md
3. Ensure backwards compatibility or document breaking changes
4. Follow the existing parameter naming conventions

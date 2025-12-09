# Actions Usage Guide

This guide shows how to integrate the custom actions into your workflow.

## Overview

We've created 3 reusable actions:
1. **docker-build-push** - Build and push Docker images
2. **trivy-scan** - Security vulnerability scanning
3. **helm-publish** - Publish Helm charts to GitHub Pages

## Integration Example

Here's how to refactor your current workflow to use these actions:

### Before (Inline Steps)

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 8
        uses: actions/setup-java@v4
        with:
          java-version: '8'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build with Maven
        working-directory: ./backend
        run: mvn clean package -DskipTests

      - name: Run unit tests
        working-directory: ./backend
        run: mvn test

      - name: Get version
        id: get_version
        working-directory: ./backend
        run: |
          VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
          echo "version=$VERSION" >> $GITHUB_OUTPUT

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          file: ./backend/docker/Dockerfile
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/backend:${{ steps.get_version.outputs.version }}-${{ github.run_number }}
            ghcr.io/${{ github.repository_owner }}/backend:latest
```

### After (Using Custom Actions)

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      image-ref: ${{ steps.docker.outputs.image-ref }}
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 8
        uses: actions/setup-java@v4
        with:
          java-version: '8'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build with Maven
        working-directory: ./backend
        run: mvn clean package -DskipTests

      - name: Run unit tests
        working-directory: ./backend
        run: mvn test

      - name: Generate version tag
        id: version
        working-directory: ./backend
        run: |
          BASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
          BUILD_NUM=${{ github.run_number }}
          SHORT_SHA=${GITHUB_SHA::8}
          VERSION="${BASE_VERSION}-build.${BUILD_NUM}-${SHORT_SHA}"
          echo "version=${VERSION}" >> $GITHUB_OUTPUT

      - name: Build and Push Docker Image
        id: docker
        uses: ./.github/actions/docker-build-push
        with:
          context: ./backend
          dockerfile: docker/Dockerfile
          image-name: ${{ github.repository_owner }}/backend
          image-tag: ${{ steps.version.outputs.version }}
          push: ${{ github.event_name == 'push' }}
          tag-latest: ${{ github.ref == 'refs/heads/master' }}
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}

  security-scan:
    runs-on: ubuntu-latest
    needs: build-and-test
    if: always()
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Scan Docker Image
        uses: ./.github/actions/trivy-scan
        with:
          image-ref: ${{ needs.build-and-test.outputs.image-ref }}
          severity: CRITICAL,HIGH
          exit-code: '0'
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}

  publish-chart:
    runs-on: ubuntu-latest
    needs: [build-and-test, security-scan]
    if: github.event_name == 'push' && (github.ref == 'refs/heads/master' || github.ref == 'refs/heads/main')
    permissions:
      contents: write
      pages: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Publish Helm Chart
        uses: ./.github/actions/helm-publish
        with:
          chart-path: sre/helm/backend
          token: ${{ secrets.GITHUB_TOKEN }}
```

## Key Improvements

### 1. Separation of Concerns
- **Build job**: Compile, test, build Docker image
- **Security job**: Scan for vulnerabilities (runs in parallel)
- **Publish job**: Publish Helm chart (only on master)

### 2. Better Version Tagging
```yaml
# Old: 1.0.0-123
version: 1.0.0-123

# New: 1.0.0-build.123-abc1234
version: 1.0.0-build.123-abc1234
```

### 3. Conditional Docker Push
```yaml
push: ${{ github.event_name == 'push' }}  # Only push on merge, not on PR
tag-latest: ${{ github.ref == 'refs/heads/master' }}  # Latest only for master
```

### 4. Security Scanning
- Runs in parallel with other jobs
- Uploads to GitHub Security tab
- Doesn't block the build (exit-code: '0')

### 5. Helm Publishing
- Only runs on master branch pushes
- Validates before publishing
- Generates install instructions

## Progressive Enhancement

You can adopt these actions gradually:

### Phase 1: Add Docker Action Only
```yaml
- name: Build Docker Image
  uses: ./.github/actions/docker-build-push
  with:
    context: ./backend
    image-name: ${{ github.repository_owner }}/backend
    image-tag: ${{ steps.version.outputs.version }}
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### Phase 2: Add Security Scanning
```yaml
- name: Scan Image
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ${{ steps.docker.outputs.image-ref }}
```

### Phase 3: Add Helm Publishing
```yaml
- name: Publish Chart
  uses: ./.github/actions/helm-publish
  with:
    chart-path: sre/helm/backend
    token: ${{ secrets.GITHUB_TOKEN }}
```

## Complete Refactored Workflow

Here's a complete example with all best practices:

```yaml
name: Backend Service CI/CD

on:
  push:
    branches: [master, main]
    paths:
      - 'backend/**'
      - 'sre/helm/backend/**'
      - '.github/workflows/**'
  pull_request:
    branches: [master, main]
    paths:
      - 'backend/**'
      - 'sre/helm/backend/**'
      - '.github/workflows/**'
  workflow_dispatch:

concurrency:
  group: backend-ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-and-test:
    name: Build and Test
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      image-ref: ${{ steps.docker.outputs.image-ref }}
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 8
        uses: actions/setup-java@v4
        with:
          java-version: '8'
          distribution: 'temurin'
          cache: 'maven'

      - name: Build with Maven
        working-directory: ./backend
        run: mvn clean package -DskipTests

      - name: Run unit tests
        working-directory: ./backend
        run: mvn test

      - name: Generate version tag
        id: version
        working-directory: ./backend
        run: |
          BASE_VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
          BUILD_NUM=${{ github.run_number }}
          SHORT_SHA=${GITHUB_SHA::8}
          VERSION="${BASE_VERSION}-build.${BUILD_NUM}-${SHORT_SHA}"
          echo "version=${VERSION}" >> $GITHUB_OUTPUT
          echo "Generated version: ${VERSION}"

      - name: Build and Push Docker Image
        id: docker
        uses: ./.github/actions/docker-build-push
        with:
          context: ./backend
          dockerfile: docker/Dockerfile
          platforms: linux/amd64,linux/arm64
          image-name: ${{ github.repository_owner }}/backend
          image-tag: ${{ steps.version.outputs.version }}
          push: ${{ github.event_name == 'push' }}
          tag-latest: ${{ github.ref == 'refs/heads/master' || github.ref == 'refs/heads/main' }}
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: build-and-test
    if: always()
    permissions:
      contents: read
      packages: read
      security-events: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Scan Docker Image for Vulnerabilities
        uses: ./.github/actions/trivy-scan
        with:
          image-ref: ${{ needs.build-and-test.outputs.image-ref }}
          severity: CRITICAL,HIGH
          exit-code: '0'
          ignore-unfixed: false
          upload-sarif: true
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}

  publish-helm-chart:
    name: Publish Helm Chart
    runs-on: ubuntu-latest
    needs: [build-and-test, security-scan]
    if: github.event_name == 'push' && (github.ref == 'refs/heads/master' || github.ref == 'refs/heads/main')
    permissions:
      contents: write
      pages: write
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Publish Helm Chart to GitHub Pages
        uses: ./.github/actions/helm-publish
        with:
          chart-path: sre/helm/backend
          helm-version: v3.14.0
          skip-existing: true
          token: ${{ secrets.GITHUB_TOKEN }}

  summary:
    name: Workflow Summary
    runs-on: ubuntu-latest
    needs: [build-and-test, security-scan, publish-helm-chart]
    if: always()
    steps:
      - name: Generate Summary
        run: |
          echo "## 🚀 Backend CI/CD Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "**Branch:** \`${{ github.ref_name }}\`" >> $GITHUB_STEP_SUMMARY
          echo "**Commit:** [\`${GITHUB_SHA::8}\`](${{ github.server_url }}/${{ github.repository }}/commit/${{ github.sha }})" >> $GITHUB_STEP_SUMMARY
          echo "**Triggered by:** ${{ github.event_name }}" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Job | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-----|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Build & Test | ${{ needs.build-and-test.result == 'success' && '✅' || '❌' }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Security Scan | ${{ needs.security-scan.result == 'success' && '✅' || '❌' }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Publish Chart | ${{ needs.publish-helm-chart.result == 'success' && '✅' || (needs.publish-helm-chart.result == 'skipped' && '⏭️' || '❌') }} |" >> $GITHUB_STEP_SUMMARY
```

## Benefits of This Approach

### 1. Reusability
- Actions can be used in other workflows
- Easy to maintain in one place
- Consistent behavior across workflows

### 2. Readability
- Workflow is easier to understand
- Each job has a clear purpose
- Less boilerplate code

### 3. Flexibility
- Easy to add/remove steps
- Parameterized behavior
- Conditional execution

### 4. Maintainability
- Updates in one place affect all usages
- Well-documented with READMEs
- Clear inputs and outputs

### 5. Best Practices
- Security scanning integrated
- Conditional Docker push
- Proper permissions
- Concurrency control

## Migration Checklist

- [ ] Create the three action directories
- [ ] Test docker-build-push action in isolation
- [ ] Test trivy-scan action in isolation
- [ ] Test helm-publish action in isolation
- [ ] Refactor main workflow to use actions
- [ ] Test complete workflow on feature branch
- [ ] Verify security scanning appears in Security tab
- [ ] Verify Helm chart publishes to GitHub Pages
- [ ] Update documentation
- [ ] Merge to master

## Troubleshooting

### Actions not found
- Verify action paths: `./.github/actions/action-name`
- Ensure action.yaml exists in each directory
- Check out code before using actions

### Permissions errors
- Add required permissions to job:
  ```yaml
  permissions:
    contents: write
    packages: write
    security-events: write
  ```

### Docker push fails on PRs
- This is intentional! Set `push: false` for PRs
- Or use: `push: ${{ github.event_name == 'push' }}`

### Security tab not showing results
- Verify `security-events: write` permission
- Private repos need GitHub Advanced Security
- Wait a few minutes for processing

## Next Steps

1. Review the complete workflow example
2. Test actions individually
3. Refactor your workflow gradually
4. Monitor for any issues
5. Document any custom configurations

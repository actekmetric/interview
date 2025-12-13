# Docker Build Action

Builds multi-platform Docker images locally without pushing to any registry. This action is designed to work independently of registry operations, making it suitable for pull requests and validation workflows.

## Features

- ✅ Multi-platform builds (linux/amd64, linux/arm64, etc.)
- ✅ GitHub Actions cache optimization
- ✅ Builds locally without requiring registry credentials
- ✅ QEMU and Buildx setup included
- ✅ Flexible image loading for scanning
- ✅ Build arguments support

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `context` | Build context directory | Yes | - |
| `dockerfile` | Dockerfile path relative to context | No | `Dockerfile` |
| `platforms` | Target platforms (comma-separated) | No | `linux/amd64,linux/arm64` |
| `image-name` | Image name without registry | Yes | - |
| `image-tag` | Image tag | Yes | - |
| `build-args` | Build arguments (key=value, one per line) | No | `` |
| `load` | Load image to local Docker (required for scanning) | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `image-ref` | Full image reference with tag |
| `digest` | Image digest (sha256) |

## Usage

### Basic Usage (PRs and Testing)

```yaml
- name: Build Docker Image
  id: docker
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: 1.0.0-build.123-abc1234
```

### With Custom Dockerfile Location

```yaml
- name: Build Docker Image
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    dockerfile: docker/Dockerfile
    image-name: backend
    image-tag: v1.2.3
```

### Multi-Platform Build (No Local Load)

```yaml
- name: Build Multi-Platform Image
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: ${{ steps.version.outputs.version }}
    platforms: linux/amd64,linux/arm64
    load: false  # Can't load multi-platform locally
```

### Single Platform for Scanning

```yaml
- name: Build for Scanning
  id: docker
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: scan-${{ github.sha }}
    platforms: linux/amd64  # Single platform for local scanning
    load: true  # Load to local Docker for Trivy

- name: Scan Image
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ${{ steps.docker.outputs.image-ref }}
```

### With Build Arguments

```yaml
- name: Build with Arguments
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: latest
    build-args: |
      APP_VERSION=1.0.0
      BUILD_DATE=${{ github.event.head_commit.timestamp }}
      GIT_COMMIT=${{ github.sha }}
```

## How It Works

1. **Setup QEMU** - Enables cross-platform emulation
2. **Setup Buildx** - Configures Docker Buildx builder
3. **Prepare Metadata** - Generates image reference
4. **Build Image** - Builds image with cache optimization (no push)
5. **Summary** - Generates build details

## Platforms

Supported platforms depend on your runner and QEMU:

- `linux/amd64` - x86_64 Linux (most common)
- `linux/arm64` - ARM 64-bit (Apple Silicon, AWS Graviton)
- `linux/arm/v7` - ARM 32-bit v7
- `linux/arm/v6` - ARM 32-bit v6
- `linux/386` - x86 32-bit Linux

**Default:** `linux/amd64,linux/arm64` (covers most use cases)

## Cache Optimization

This action uses GitHub Actions cache (`type=gha`) for:
- ✅ Layer caching between builds
- ✅ Faster rebuilds when dependencies don't change
- ✅ Reduced build times by 50-80%

Cache is shared across:
- Same repository
- Same branch
- Workflow runs

## Load vs Multi-Platform

**Important:** You cannot load multi-platform images to local Docker. Choose one:

**Option 1: Load for Scanning (Single Platform)**
```yaml
platforms: linux/amd64
load: true  # Loads to local Docker for Trivy scan
```

**Option 2: Multi-Platform (No Local Load)**
```yaml
platforms: linux/amd64,linux/arm64
load: false  # Build only, can't scan locally
```

**Recommended for CI Workflows:**
- **PRs**: Use single platform (`linux/amd64`) with `load: true` for scanning
- **Deployable branches**: Use multi-platform with `load: false`, publish to registry

## Build Arguments

Pass build-time variables to Dockerfile:

```yaml
build-args: |
  VERSION=${{ steps.version.outputs.version }}
  COMMIT=${{ github.sha }}
  BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Access in Dockerfile:
```dockerfile
ARG VERSION
ARG COMMIT
ARG BUILD_DATE

LABEL version="${VERSION}" \
      commit="${COMMIT}" \
      build-date="${BUILD_DATE}"
```

## Requirements

- Dockerfile must exist at specified location
- For multi-platform: Runner must support QEMU
- For loading locally: Must use single platform build

## Troubleshooting

**"No space left on device":**
- Build produces large images
- Clean up old images: `docker system prune -af`
- Use smaller base images

**"Multiple platforms not supported":**
- Verify QEMU setup step succeeded
- Check runner supports multi-platform builds
- Try single platform build first

**"Cannot load multi-platform image":**
- Set `load: false` for multi-platform builds
- Or use single platform: `platforms: linux/amd64`

**Slow builds:**
- Verify cache is working (check logs for "cache hit")
- Optimize Dockerfile layer ordering
- Use smaller base images

## Example Output

The action generates a summary like:

```
## 🐳 Docker Image Build

**Image:** `backend:1.0.0-build.123-abc1234`
**Platforms:** `linux/amd64,linux/arm64`
**Built:** ✅ Success (local only, not pushed)
```

## Comparison with docker-build-push

**This action (docker-build):**
- Builds images locally only
- No registry authentication required
- Suitable for PRs and validation
- Separates build from publish concerns

**Use with ecr-publish:**
After building with this action, use the `ecr-publish` action to push the image to Amazon ECR:

```yaml
- name: Build Docker Image
  id: docker
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: ${{ steps.version.outputs.version }}

- name: Publish to ECR
  if: github.event_name == 'push'
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
    image-name: backend
    source-tag: ${{ steps.version.outputs.version }}
    target-tag: ${{ steps.version.outputs.version }}
```

**Advantages of this approach:**
- ✅ PRs can build and scan without AWS credentials
- ✅ Clear separation of concerns
- ✅ Easier to test builds locally
- ✅ More flexible conditional logic

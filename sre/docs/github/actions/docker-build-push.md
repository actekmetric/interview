# Docker Build and Push Action

Builds multi-platform Docker images and pushes to Amazon ECR with caching optimization.

## Features

- ✅ Multi-platform builds (linux/amd64, linux/arm64, etc.)
- ✅ GitHub Actions cache optimization
- ✅ Conditional push (build-only mode for PRs)
- ✅ Flexible tagging (primary tag + optional latest)
- ✅ Build arguments support
- ✅ QEMU and Buildx setup included

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `context` | Build context directory | Yes | - |
| `dockerfile` | Dockerfile path relative to context | No | `Dockerfile` |
| `platforms` | Target platforms (comma-separated) | No | `linux/amd64,linux/arm64` |
| `registry` | Container registry URL | No | `{account-id}.dkr.ecr.us-east-1.amazonaws.com` |
| `registry-username` | Registry username | Yes | - |
| `registry-password` | Registry password/token | Yes | - |
| `image-name` | Image name without registry | Yes | - |
| `image-tag` | Primary image tag | Yes | - |
| `push` | Whether to push (true/false) | No | `true` |
| `tag-latest` | Also tag as latest (true/false) | No | `false` |
| `build-args` | Build arguments (key=value, one per line) | No | `` |

## Outputs

| Output | Description |
|--------|-------------|
| `image-ref` | Full image reference with tag |
| `digest` | Image digest (sha256) |

## Usage

### Basic Usage

```yaml
- name: Build and Push Docker Image
  uses: ./.github/actions/docker-build-push
  with:
    context: ./backend
    image-name: ${{ github.repository_owner }}/backend
    image-tag: 1.0.0-build.123-abc1234
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### With Custom Dockerfile Location

```yaml
- name: Build Docker Image
  uses: ./.github/actions/docker-build-push
  with:
    context: ./backend
    dockerfile: docker/Dockerfile
    image-name: myorg/backend
    image-tag: v1.2.3
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### Conditional Push (PRs Build Only)

```yaml
- name: Build and Maybe Push
  uses: ./.github/actions/docker-build-push
  with:
    context: ./backend
    image-name: ${{ github.repository_owner }}/backend
    image-tag: ${{ steps.version.outputs.tag }}
    push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/master' }}
    tag-latest: ${{ github.ref == 'refs/heads/master' }}
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### With Build Arguments

```yaml
- name: Build with Arguments
  uses: ./.github/actions/docker-build-push
  with:
    context: ./backend
    image-name: myorg/backend
    image-tag: latest
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
    build-args: |
      APP_VERSION=1.0.0
      BUILD_DATE=${{ github.event.head_commit.timestamp }}
      GIT_COMMIT=${{ github.sha }}
```

### Single Platform Build

```yaml
- name: Build AMD64 Only
  uses: ./.github/actions/docker-build-push
  with:
    context: ./backend
    platforms: linux/amd64
    image-name: myorg/backend
    image-tag: amd64-only
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

## How It Works

1. **Setup QEMU** - Enables cross-platform emulation
2. **Setup Buildx** - Configures Docker Buildx builder
3. **Registry Login** - Authenticates to container registry
4. **Prepare Tags** - Generates image tags (primary + optional latest)
5. **Build & Push** - Builds multi-platform image with cache optimization
6. **Summary** - Generates pull command and build details

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

## Conditional Push Strategy

**For Pull Requests:**
```yaml
push: false  # Build to validate, don't push
```

**For Master Branch:**
```yaml
push: true
tag-latest: true  # Also tag as latest
```

**Example:**
```yaml
push: ${{ github.event_name == 'push' }}
tag-latest: ${{ github.ref == 'refs/heads/master' }}
```

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
- Registry credentials must have push permissions
- For multi-platform: Runner must support QEMU

## Troubleshooting

**"No space left on device":**
- Build produces large images
- Clean up old images: `docker system prune -af`
- Use smaller base images

**"Multiple platforms not supported":**
- Verify QEMU setup step succeeded
- Check runner supports multi-platform builds
- Try single platform build first

**"Failed to push: unauthorized":**
- Verify registry-password has correct token
- For GHCR, ensure token has `packages: write` permission
- Check repository access permissions

**Slow builds:**
- Verify cache is working (check logs for "cache hit")
- Optimize Dockerfile layer ordering
- Use smaller base images
- Consider single platform builds

## Example Output

The action generates a summary like:

```
## 🐳 Docker Image Build

**Image:** `{account-id}.dkr.ecr.us-east-1.amazonaws.com/myorg/backend:1.0.0-build.123-abc1234`
**Platforms:** `linux/amd64,linux/arm64`
**Pushed:** true

### 📥 Pull Command
```bash
docker pull {account-id}.dkr.ecr.us-east-1.amazonaws.com/myorg/backend:1.0.0-build.123-abc1234
```

**Digest:** `sha256:abc123...`
```

## Comparison with Other Approaches

**This action:**
- Uses inline tagging logic (simple)
- Direct docker/build-push-action usage
- Optimized for Amazon ECR

**Alternative approaches:**
- docker/metadata-action (more complex, more features)
- Manual docker commands (less optimized)
- Separate build and push steps (slower)

**Our choice:** Balance simplicity with essential features.

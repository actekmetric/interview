# Tekmetric Helm Chart Repository

This document explains how to use the Tekmetric Helm charts hosted on GitHub Pages via GitHub Releases.

## Repository URL

The Helm chart repository is hosted at:
```
https://actekmetric.github.io/interview/
```

## How It Works

This repository uses the **chart-releaser** approach:
- **Chart packages** (.tgz files) are stored in GitHub Releases (not in Git)
- **Repository index** (index.yaml) is hosted on GitHub Pages (`gh-pages` branch)
- No binary files committed to the main repository
- Clean, conflict-free workflow

## Quick Start

### 1. Add the Helm Repository

```bash
helm repo add tekmetric https://actekmetric.github.io/interview/
helm repo update
```

### 2. Search Available Charts

```bash
helm search repo tekmetric
```

Expected output:
```
NAME                              CHART VERSION   APP VERSION   DESCRIPTION
tekmetric/tekmetric-common-chart  0.1.0          1.0           Tekmetric common helm functionality
```

### 3. Install a Chart

```bash
# Install with default values
helm install my-service tekmetric/tekmetric-common-chart

# Install with custom values
helm install my-service tekmetric/tekmetric-common-chart \
  --set image.repository=docker.io \
  --set image.name=myapp \
  --set image.tag=1.0.0

# Install with values file
helm install my-service tekmetric/tekmetric-common-chart -f values.yaml
```

### 4. Upgrade a Release

```bash
helm upgrade my-service tekmetric/tekmetric-common-chart -f values.yaml
```

### 5. Uninstall a Release

```bash
helm uninstall my-service
```

## Repository Structure

```
interview/
├── .github/
│   └── workflows/
│       └── charts/
│           └── common-helm-chart.yml  # Automated release workflow
└── charts/
    ├── HELM_REPOSITORY.md            # This file
    ├── SETUP_SUMMARY.md              # Setup guide
    ├── README.md                     # Documentation
    ├── tekmetric-common-chart/       # Chart source (Git)
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   ├── templates/
    │   └── README.md
    └── tests/
        └── values.yaml
```

**Note:** Chart packages (.tgz files) are NOT stored in Git. They are:
- Packaged during CI/CD
- Published to GitHub Releases
- Referenced by index.yaml on gh-pages branch

## Automated Releases

### How It Works

The `chart-releaser-action` automatically:

1. **Detects Changes**: Monitors `charts/tekmetric-common-chart/` for changes
2. **Lints Chart**: Validates chart syntax and structure
3. **Packages Chart**: Creates `.tgz` package
4. **Creates Release**: Publishes to GitHub Releases with chart package
5. **Updates Index**: Updates `index.yaml` on `gh-pages` branch
6. **No Git Commits**: No binary files committed to repository

### Workflow Triggers

The workflow runs when:
- Push to `master`/`main` branch with changes in:
  - `charts/tekmetric-common-chart/**`
  - `.github/workflows/charts/common-helm-chart.yml`
- Manual trigger via GitHub Actions UI

### Manual Trigger

1. Go to: https://github.com/actekmetric/interview/actions
2. Select "Release Common Helm Chart"
3. Click "Run workflow"

## Chart Versioning

### Version Management

Chart versions are defined in `charts/tekmetric-common-chart/Chart.yaml`:

```yaml
apiVersion: v1
name: tekmetric-common-chart
version: 0.1.0      # Increment this for new releases
appVersion: "1.0"   # Application version
```

### Releasing a New Version

```bash
# 1. Update version in Chart.yaml
cd charts/tekmetric-common-chart
# Edit Chart.yaml: version: 0.2.0

# 2. Commit and push
git add Chart.yaml
git commit -m "Bump chart version to 0.2.0"
git push origin master

# 3. Workflow automatically:
#    - Packages chart as tekmetric-common-chart-0.2.0.tgz
#    - Creates GitHub Release v0.2.0
#    - Attaches .tgz to release
#    - Updates index.yaml on gh-pages
```

### Version History

View all chart versions:
```bash
helm search repo tekmetric/tekmetric-common-chart --versions
```

Or browse releases:
```
https://github.com/actekmetric/interview/releases
```

## GitHub Releases Storage

### Where Are Charts Stored?

Charts are stored as release assets:
- **Location**: GitHub Releases
- **URL Pattern**: `https://github.com/actekmetric/interview/releases/download/tekmetric-common-chart-{VERSION}/tekmetric-common-chart-{VERSION}.tgz`
- **Example**: `https://github.com/actekmetric/interview/releases/download/tekmetric-common-chart-0.1.0/tekmetric-common-chart-0.1.0.tgz`

### Viewing Releases

Browse all chart releases:
```
https://github.com/actekmetric/interview/releases
```

Each release contains:
- Chart package (.tgz file)
- Release notes (auto-generated from Chart.yaml)
- Git tag (e.g., `tekmetric-common-chart-0.1.0`)

## GitHub Pages Configuration

### What's on gh-pages Branch?

The `gh-pages` branch contains ONLY:
- `index.yaml` - Helm repository index
- No chart packages (they're in Releases)
- Automatically managed by chart-releaser

### Initial Setup

1. **Enable GitHub Pages**:
   - Go to: https://github.com/actekmetric/interview/settings/pages
   - Source: Deploy from a branch
   - Branch: `gh-pages`
   - Folder: `/ (root)`
   - Click Save

2. **First Run**:
   - Push changes to trigger workflow
   - Workflow creates `gh-pages` branch
   - GitHub Pages becomes available in 2-3 minutes

## Testing Locally

Before pushing changes:

```bash
# Lint the chart
helm lint charts/tekmetric-common-chart/

# Template the chart (dry-run)
helm template test-release charts/tekmetric-common-chart/ -f tests/values.yaml

# Package locally (optional)
helm package charts/tekmetric-common-chart/

# Install from local directory (testing)
helm install test-release ./charts/tekmetric-common-chart/ -f tests/values.yaml --dry-run
```

## Troubleshooting

### Chart Not Found

```bash
# Update repository cache
helm repo update

# List all versions
helm search repo tekmetric -l

# Check if repository is added
helm repo list
```

### Workflow Issues

**Check workflow status:**
```
https://github.com/actekmetric/interview/actions
```

**Common issues:**
- Chart version not incremented (workflow skips existing versions)
- GitHub token permissions (should be automatic)
- Path configuration incorrect

### Verify Repository

```bash
# Check index is accessible
curl https://actekmetric.github.io/interview/index.yaml

# Check specific chart package (replace VERSION)
curl -I https://github.com/actekmetric/interview/releases/download/tekmetric-common-chart-VERSION/tekmetric-common-chart-VERSION.tgz
```

### Force Rebuild

If you need to rebuild without version change:

1. Delete the GitHub Release for that version
2. Delete the Git tag: `git push origin :refs/tags/tekmetric-common-chart-X.Y.Z`
3. Re-run the workflow

## Benefits of This Approach

✅ **No Binary Files in Git**: Keeps repository clean and fast
✅ **No Merge Conflicts**: No chart packages to conflict
✅ **Versioned Releases**: Clear version history in GitHub Releases
✅ **Efficient Storage**: GitHub handles package hosting
✅ **Standard Practice**: Uses official chart-releaser-action
✅ **Easy Rollback**: Download any version from Releases
✅ **Bandwidth**: GitHub's CDN serves chart packages

## URLs

| Purpose | URL |
|---------|-----|
| Helm Repository | https://actekmetric.github.io/interview/ |
| Repository Index | https://actekmetric.github.io/interview/index.yaml |
| GitHub Releases | https://github.com/actekmetric/interview/releases |
| GitHub Actions | https://github.com/actekmetric/interview/actions |
| Pages Settings | https://github.com/actekmetric/interview/settings/pages |

## Documentation

- **Setup Guide**: [SETUP_SUMMARY.md](./SETUP_SUMMARY.md)
- **Chart Documentation**: [README.md](./README.md)
- **Chart README**: [tekmetric-common-chart/README.md](./tekmetric-common-chart/README.md)
- **Values Reference**: [tekmetric-common-chart/values.yaml](./tekmetric-common-chart/values.yaml)

## Support

- **Issues**: https://github.com/actekmetric/interview/issues
- **Chart Source**: https://github.com/actekmetric/interview/tree/master/charts
- **chart-releaser**: https://github.com/helm/chart-releaser-action

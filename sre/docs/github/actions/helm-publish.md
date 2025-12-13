# Helm Chart Publish Action

Lints, validates, and publishes Helm charts to GitHub Pages using chart-releaser.

## Features

- ✅ Automatic chart linting with `helm lint`
- ✅ Template validation with `helm template --dry-run`
- ✅ Publishing to GitHub Pages via chart-releaser
- ✅ Version detection from Chart.yaml
- ✅ Skip existing releases option
- ✅ Generates install instructions in summary

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `chart-path` | Path to the Helm chart directory | Yes | - |
| `charts-repo-url` | GitHub Pages URL for charts | No | Auto-detected |
| `skip-existing` | Skip if version already exists | No | `true` |
| `helm-version` | Helm version to use | No | `v3.14.0` |
| `token` | GitHub token for chart-releaser | Yes | - |

## Outputs

| Output | Description |
|--------|-------------|
| `chart-version` | Version of the published chart |
| `chart-name` | Name of the published chart |

## Usage

### Basic Usage

```yaml
- name: Publish Helm Chart
  uses: ./.github/actions/helm-publish
  with:
    chart-path: sre/helm/backend
    token: ${{ secrets.GITHUB_TOKEN }}
```

### Advanced Usage

```yaml
- name: Publish Helm Chart
  uses: ./.github/actions/helm-publish
  with:
    chart-path: sre/helm/backend
    charts-repo-url: https://myorg.github.io/charts
    skip-existing: true
    helm-version: v3.14.0
    token: ${{ secrets.GITHUB_TOKEN }}
```

### With Conditional Execution

```yaml
- name: Publish Helm Chart
  if: github.event_name == 'push' && github.ref == 'refs/heads/master'
  uses: ./.github/actions/helm-publish
  with:
    chart-path: sre/helm/backend
    token: ${{ secrets.GITHUB_TOKEN }}
```

## How It Works

1. **Configure Git** - Sets up git user for chart-releaser
2. **Install Helm** - Installs specified Helm version
3. **Lint Chart** - Validates chart structure and syntax
4. **Get Chart Info** - Extracts name and version from Chart.yaml
5. **Validate Templates** - Tests template rendering with dry-run
6. **Publish** - Uses chart-releaser to publish to GitHub Pages
7. **Summary** - Generates installation instructions

## Requirements

- Chart must have valid Chart.yaml with name and version
- GitHub Pages must be enabled for the repository
- Token must have `contents: write` permission

## Chart Structure

Your chart directory should look like:

```
sre/helm/backend/
├── Chart.yaml          # Required: chart metadata
├── values.yaml         # Required: default values
├── templates/          # Required: Kubernetes templates
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ...
└── charts/             # Optional: dependencies
```

## Troubleshooting

**Chart-releaser fails with "Release already exists":**
- Set `skip-existing: true` to ignore existing releases
- Or increment the version in Chart.yaml

**"Chart not found" error:**
- Verify `chart-path` points to directory containing Chart.yaml
- Use relative path from repository root

**GitHub Pages not updating:**
- Check that GitHub Pages is enabled in repository settings
- Verify the `gh-pages` branch exists
- Check token permissions include `contents: write`

## Differences from Other Implementations

This action uses **chart-releaser** to publish to **GitHub Pages**, which is different from:
- ChartMuseum-based approaches (requires separate infrastructure)
- OCI registry approaches (requires different tooling)
- Manual packaging approaches (less automation)

**Advantages of this approach:**
- ✅ Free hosting on GitHub Pages
- ✅ No additional infrastructure required
- ✅ Integrated with GitHub releases
- ✅ Simple and maintainable

## Example Output

The action generates a summary like:

```
## 📦 Helm Chart Published

**Chart Name:** `backend`
**Version:** `0.1.0`
**Repository:** https://myorg.s3://tekmetric-helm-charts-{account-id}/charts

### 📥 Install Command
```bash
helm repo add my-charts https://myorg.s3://tekmetric-helm-charts-{account-id}/charts
helm repo update
helm install my-release my-charts/backend
```
```

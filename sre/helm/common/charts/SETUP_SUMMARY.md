# Helm Chart Setup Summary

## ✅ Completed Setup

Your Tekmetric Helm chart repository is configured using **GitHub Releases** (no binary files in Git)!

## 📁 Clean Repository Structure

```
interview/                                # Root repository
├── .github/
│   └── workflows/
│       └── charts/
│           └── common-helm-chart.yml    # Automated release workflow
└── charts/
    ├── HELM_REPOSITORY.md               # Usage guide
    ├── SETUP_SUMMARY.md                 # This file
    ├── README.md                        # Documentation
    ├── tekmetric-common-chart/          # Chart source (in Git)
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   ├── README.md
    │   └── templates/
    │       ├── deployment.yaml
    │       ├── service.yaml
    │       ├── ingress.yaml
    │       ├── hpa.yaml
    │       ├── pdb.yaml
    │       ├── _names.tpl
    │       ├── _labels.tpl
    │       ├── _environment.tpl
    │       └── _observability.tpl
    └── tests/
        └── values.yaml

# Chart packages (.tgz) are NOT in Git!
# They are stored in GitHub Releases
```

## 🎯 How It Works (chart-releaser approach)

1. **Source Code**: Only chart source files in Git (YAML templates)
2. **Packaging**: Workflow packages charts during CI/CD
3. **Storage**: Chart packages stored in GitHub Releases (not Git)
4. **Index**: `index.yaml` on `gh-pages` branch points to Release assets
5. **Clean Repo**: No binary files, no conflicts, fast clones

## 🚀 Setup Steps

### 1. Push Changes to GitHub

```bash
# From the repository root
cd /Users/acolta/work/homelab/interview

# Check status
git status

# Add changes
git add .

# Commit
git commit -m "Add Tekmetric Helm chart with GitHub Releases"

# Push to master
git push origin master
```

### 2. Enable GitHub Pages (One-Time Setup)

1. Go to: https://github.com/actekmetric/interview/settings/pages
2. Under "Build and deployment":
   - **Source**: Deploy from a branch
   - **Branch**: `gh-pages` (will be created by workflow)
   - **Folder**: `/ (root)`
3. Click **Save**

### 3. Trigger First Release

The workflow will automatically:
- Create `gh-pages` branch with `index.yaml`
- Package the chart as `tekmetric-common-chart-0.1.0.tgz`
- Create GitHub Release with the package
- Update index to point to the Release asset

**Option A: Automatic (recommended)**
- Workflow triggers when you push to master

**Option B: Manual trigger**
1. Go to: https://github.com/actekmetric/interview/actions
2. Select "Release Common Helm Chart"
3. Click "Run workflow"

### 4. Verify Setup (After ~3 minutes)

```bash
# Check index is accessible
curl https://actekmetric.github.io/interview/index.yaml

# Add the repository
helm repo add tekmetric https://actekmetric.github.io/interview/
helm repo update

# Search for charts
helm search repo tekmetric

# View chart details
helm show chart tekmetric/tekmetric-common-chart
```

## 📦 Using the Helm Repository

### Add Repository

```bash
helm repo add tekmetric https://actekmetric.github.io/interview/
helm repo update
```

### Install Chart

```bash
# Basic installation
helm install my-service tekmetric/tekmetric-common-chart

# With custom values
helm install my-service tekmetric/tekmetric-common-chart \
  --set image.repository=docker.io \
  --set image.name=myapp \
  --set image.tag=1.0.0

# With values file
helm install my-service tekmetric/tekmetric-common-chart -f values.yaml
```

## 🔄 Releasing New Versions

### Update Chart Version

```bash
cd charts/tekmetric-common-chart

# Edit Chart.yaml
# Change: version: 0.1.0 → version: 0.2.0

git add Chart.yaml
git commit -m "Bump chart version to 0.2.0"
git push origin master
```

### What Happens Automatically

1. ✅ Workflow detects change
2. ✅ Lints chart
3. ✅ Packages as `tekmetric-common-chart-0.2.0.tgz`
4. ✅ Creates GitHub Release `tekmetric-common-chart-0.2.0`
5. ✅ Attaches package to release
6. ✅ Updates `index.yaml` on `gh-pages`
7. ✅ Chart available via Helm immediately

## 📍 Where Are Things Stored?

| Item | Location | In Git? |
|------|----------|---------|
| Chart source (YAML) | `charts/tekmetric-common-chart/` | ✅ Yes |
| Chart package (.tgz) | GitHub Releases | ❌ No |
| Repository index | `gh-pages` branch | ✅ Yes (auto-managed) |
| Workflow | `.github/workflows/` | ✅ Yes |

## ✨ Benefits

✅ **No Binary Files in Git**
- Clean repository
- Fast clones
- No merge conflicts on packages

✅ **Efficient Storage**
- GitHub handles package hosting
- CDN for fast downloads
- No repository bloat

✅ **Version Control**
- Clear release history
- Easy to find specific versions
- Downloadable from Releases page

✅ **Standard Practice**
- Uses official `chart-releaser-action`
- Follows Helm community conventions
- Compatible with all Helm clients

## 🌐 Important URLs

| Purpose | URL |
|---------|-----|
| **Helm Repository** | https://actekmetric.github.io/interview/ |
| Repository Index | https://actekmetric.github.io/interview/index.yaml |
| **GitHub Releases** | https://github.com/actekmetric/interview/releases |
| GitHub Actions | https://github.com/actekmetric/interview/actions |
| Pages Settings | https://github.com/actekmetric/interview/settings/pages |
| Chart Source | https://github.com/actekmetric/interview/tree/master/charts |

## 🔍 Example Release URLs

Once released, charts are available at:
```
https://github.com/actekmetric/interview/releases/download/tekmetric-common-chart-0.1.0/tekmetric-common-chart-0.1.0.tgz
```

Pattern:
```
https://github.com/{org}/{repo}/releases/download/{chart-name}-{version}/{chart-name}-{version}.tgz
```

## 🐛 Troubleshooting

### Workflow Not Running

- Check paths in workflow file match your structure
- Verify changes are in `charts/tekmetric-common-chart/**`
- Check GitHub Actions permissions

### Chart Not Found After Release

```bash
# Wait 2-3 minutes for Pages to update
# Then update Helm cache
helm repo update

# Check if index exists
curl https://actekmetric.github.io/interview/index.yaml

# Verify release exists
# Visit: https://github.com/actekmetric/interview/releases
```

### Re-release Same Version

If you need to re-release the same version:

1. Delete the GitHub Release
2. Delete the Git tag:
   ```bash
   git push origin :refs/tags/tekmetric-common-chart-0.1.0
   ```
3. Re-run the workflow

## 📚 Documentation

- **Repository Guide**: [HELM_REPOSITORY.md](./HELM_REPOSITORY.md)
- **Chart Docs**: [README.md](./README.md)
- **Chart README**: [tekmetric-common-chart/README.md](./tekmetric-common-chart/README.md)
- **Values**: [tekmetric-common-chart/values.yaml](./tekmetric-common-chart/values.yaml)

## 🎉 You're All Set!

After pushing to GitHub and enabling Pages:

```bash
helm repo add tekmetric https://actekmetric.github.io/interview/
helm install my-release tekmetric/tekmetric-common-chart
```

**Key Points:**
- ✅ No chart packages (.tgz) in Git
- ✅ Packages stored in GitHub Releases
- ✅ Clean, conflict-free workflow
- ✅ Standard Helm repository hosting

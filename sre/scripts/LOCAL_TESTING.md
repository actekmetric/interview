# Local CI Testing Guide

This guide explains how to test the PR deployment workflow locally before pushing to GitHub.

## Option 1: Direct Local Testing (Recommended - Faster)

This approach mimics the CI workflow steps locally without using GitHub Actions.

### Prerequisites
```bash
# macOS
brew install k3d helm kubectl podman

# Start podman machine (if not running)
podman machine init
podman machine start

# Verify podman is running
podman info
```

### Run the Test
```bash
cd /Users/acolta/work/homelab/interview
./sre/scripts/test-ci-locally.sh
```

### What It Does
1. Creates a k3d cluster (same as CI)
2. Builds the backend Docker image locally
3. Loads image into k3d cluster
4. Deploys using Helm with local values
5. Runs smoke tests
6. Leaves cluster running for debugging

### Time: ~2-3 minutes

### Cleanup
```bash
k3d cluster delete backend-test-local
```

---

## Option 2: Test with act (GitHub Actions Simulation)

⚠️ **Not Recommended on macOS with Podman** - act has issues with podman on macOS due to nested virtualization and socket path incompatibilities.

### Why It Doesn't Work Well
- act expects Docker socket at standard location
- Podman on macOS uses VM with different socket path
- Nested containers (k3d inside act) don't work reliably
- Complex setup with limited benefits

### Alternative: Use Docker Desktop (if needed)
If you absolutely need to test with act:
1. Install Docker Desktop: `brew install --cask docker`
2. Start Docker Desktop
3. Run: `act pull_request --job build-and-test`

### Recommendation
**Use Option 1 (Direct Local Testing)** instead - it's faster, more reliable, and doesn't require act or Docker Desktop

---

## Option 3: Manual Step-by-Step Testing

Test individual components manually:

### 1. Test Helm Chart Locally
```bash
# Build dependencies
cd sre/helm/backend
helm dependency build

# Dry-run deployment (no cluster needed)
helm template backend . \
  --values values-local-kind-testing.yaml \
  --set tekmetric-common-chart.image.tag=test

# Lint chart
helm lint .
```

### 2. Create Test Cluster
```bash
# Create k3d cluster
k3d cluster create test \
  --agents 0 \
  --k3s-arg "--disable=traefik,metrics-server@server:0" \
  --port 8080:30080@loadbalancer

# Verify
kubectl get nodes
```

### 3. Build and Load Image
```bash
# Build image
cd backend
podman build -t ghcr.io/actekmetric/backend:local -f docker/Dockerfile .

# Load into k3d
podman save ghcr.io/actekmetric/backend:local | k3d image import -c test -
```

### 4. Deploy with Helm
```bash
cd sre/helm/backend
helm install backend . \
  --values values-local-kind-testing.yaml \
  --set tekmetric-common-chart.image.repository=ghcr.io/actekmetric \
  --set tekmetric-common-chart.image.tag=local \
  --set tekmetric-common-chart.image.pullPolicy=Never \
  --wait --timeout 3m
```

### 5. Test Application
```bash
# Check pods
kubectl get pods

# Check logs
kubectl logs -l app.kubernetes.io/name=backend

# Port forward
kubectl port-forward service/backend 8080:8080 &

# Test endpoint
curl http://localhost:8080/health

# Run smoke tests
./sre/scripts/smoke-tests.sh
```

### 6. Cleanup
```bash
helm uninstall backend
k3d cluster delete test
```

---

## Troubleshooting

### "Deployment is not ready"
Check pod status and logs:
```bash
kubectl get pods -A
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Image Pull Errors
If using local image, ensure `pullPolicy: Never`:
```bash
--set tekmetric-common-chart.image.pullPolicy=Never
```

### Port Already in Use
```bash
# Find and kill process using port 8080
lsof -ti:8080 | xargs kill -9
```

### k3d Cluster Won't Start
```bash
# Delete and recreate
k3d cluster delete test
podman system prune -f
```

---

## Comparison

| Method | Speed | Accuracy | Setup | Use Case |
|--------|-------|----------|-------|----------|
| Direct Local | ⚡⚡⚡ Fast | 90% | Easy | Quick iteration |
| act | ⚡ Slow | 95% | Medium | Pre-merge validation |
| Manual | ⚡⚡ Medium | 90% | Easy | Debugging specific steps |

**Recommendation**: Use **Direct Local Testing** for quick feedback during development.

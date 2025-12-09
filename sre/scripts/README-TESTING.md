# Testing the PR Workflow Locally

## ✅ Recommended: Direct Local Testing

**Use this approach** - it works perfectly with podman on macOS.

### Quick Start
```bash
cd /Users/acolta/work/homelab/interview
./sre/scripts/test-ci-locally.sh
```

### What It Does
This script mimics the GitHub Actions PR workflow locally:

1. ✅ Creates k3d cluster (using podman as container runtime)
2. ✅ Builds backend Docker image with podman
3. ✅ Loads image into k3d cluster
4. ✅ Deploys with Helm using local chart
5. ✅ Runs smoke tests
6. ✅ Leaves cluster running for debugging

### Time: 2-3 minutes vs 8-10 minutes in CI

### Prerequisites
```bash
brew install k3d helm kubectl podman
podman machine start
```

### After Testing
```bash
# View resources
kubectl get pods
kubectl logs -l app.kubernetes.io/name=backend

# Access the app
kubectl port-forward service/backend 8080:8080

# Cleanup when done
k3d cluster delete backend-test-local
```

---

## ❌ NOT Recommended: act (GitHub Actions Simulator)

**Don't use act with podman on macOS** - it has compatibility issues.

### Why It Fails
1. **Socket Path Mismatch**: act expects `/var/run/docker.sock` but podman uses `/var/folders/.../podman-machine-default-api.sock`
2. **Nested Virtualization**: macOS → podman VM → act container → k3d → your app (4 levels!)
3. **Container Runtime**: act expects Docker daemon, not podman socket
4. **Limited Value**: Even if it works, it's slower and more complex than direct testing

### Error You'll See
```
Cannot connect to the Docker daemon at unix:///run/podman/podman.sock
```

### If You Really Need act
Install Docker Desktop instead of using podman:
```bash
brew install --cask docker
# Start Docker Desktop from Applications
act pull_request --job build-and-test
```

But honestly, **direct local testing is better** - faster, simpler, more reliable.

---

## Comparison

| Method | Works with Podman? | Speed | Accuracy | Setup Complexity |
|--------|-------------------|-------|----------|------------------|
| **Direct Local** | ✅ Yes | ⚡⚡⚡ Fast (2-3 min) | 90% | Easy |
| **act** | ❌ No (needs Docker) | ⚡ Slow (5-10 min) | 95% | Complex |
| **Manual Steps** | ✅ Yes | ⚡⚡ Medium | 90% | Medium |

---

## Architecture Differences

### GitHub Actions (CI)
```
GitHub Runner (Ubuntu)
  └── Docker (native)
      └── k3d cluster
          └── Your app container
```

### Direct Local Testing (Recommended)
```
macOS
  └── Podman VM
      └── k3d cluster
          └── Your app container
```

### act with Podman (Broken)
```
macOS
  └── Podman VM
      └── act container (expects Docker)  ← FAILS HERE
          └── k3d cluster
              └── Your app container
```

---

## Troubleshooting Direct Local Testing

### "k3d cluster create failed"
```bash
# Check podman is running
podman info

# Restart podman if needed
podman machine stop
podman machine start

# Verify DOCKER_HOST
echo $DOCKER_HOST
```

### "podman build failed"
```bash
# Check you're in the right directory
pwd  # should be /Users/acolta/work/homelab/interview

# Check backend exists
ls -la backend/docker/Dockerfile
```

### "Image pull failed"
The script uses local images, not GHCR. Ensure:
```bash
--set tekmetric-common-chart.image.pullPolicy=Never
```

### "Port 8080 already in use"
```bash
lsof -ti:8080 | xargs kill -9
```

---

## Conclusion

✅ **Use `./sre/scripts/test-ci-locally.sh`** - It works great with podman!

❌ **Skip act** - It's not worth the hassle on macOS with podman

The direct testing approach gives you:
- Fast feedback (2-3 minutes)
- Real k3d cluster (same as CI)
- Full debugging access (kubectl, logs, port-forward)
- No Docker Desktop required
- Works perfectly with podman

#!/bin/bash
set -e

# Local CI Testing Script for GitHub Actions Workflow
# This script simulates the PR workflow deployment test locally

echo "=== Local PR Workflow Testing ==="
echo ""

# Configuration
CLUSTER_NAME="backend-test-local"
IMAGE_TAG="local-test"
CHART_DIR="./sre/helm/backend"

# Check prerequisites
echo "Checking prerequisites..."
command -v k3d >/dev/null 2>&1 || { echo "Error: k3d is not installed. Install with: brew install k3d"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "Error: helm is not installed. Install with: brew install helm"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl is not installed. Install with: brew install kubectl"; exit 1; }
command -v podman >/dev/null 2>&1 || { echo "Error: podman is not installed. Install with: brew install podman"; exit 1; }

# Check if podman is running
if ! podman info >/dev/null 2>&1; then
  echo "Error: Podman is not running"
  echo "Start with: podman machine start"
  exit 1
fi

# Configure k3d to use podman
# Get the socket path and ensure it's properly formatted
PODMAN_SOCKET=$(podman info --format '{{.Host.RemoteSocket.Path}}')
# Remove unix:// prefix if present, then add it back
PODMAN_SOCKET=${PODMAN_SOCKET#unix://}
export DOCKER_HOST="unix://${PODMAN_SOCKET}"
export DOCKER_SOCK="${PODMAN_SOCKET}"

echo "✓ All prerequisites installed"
echo "✓ Using podman at: $DOCKER_HOST"
echo ""

# Cleanup any existing cluster
echo "Cleaning up existing cluster..."
k3d cluster delete $CLUSTER_NAME 2>/dev/null || true
echo ""

# Create k3d cluster
echo "Creating k3d cluster..."
k3d cluster create $CLUSTER_NAME \
  --agents 0 \
  --k3s-arg "--disable=traefik,metrics-server@server:0" \
  --port 8080:30080@loadbalancer \
  --wait \
  --timeout 2m

echo "✓ Cluster created"
echo ""

# Verify cluster
echo "Verifying cluster..."
kubectl cluster-info
kubectl get nodes
echo ""

# Build backend image locally
echo "Building backend image with podman..."
cd backend
podman build -t ghcr.io/actekmetric/backend:$IMAGE_TAG -f docker/Dockerfile .
cd ..
echo "✓ Image built"
echo ""

# Load image into k3d
echo "Loading image into k3d cluster..."
# Save image from podman and load into k3d
podman save ghcr.io/actekmetric/backend:$IMAGE_TAG | k3d image import -c $CLUSTER_NAME -
echo "✓ Image loaded"
echo ""

# Add Helm repository for dependencies
echo "Adding Helm repository..."
helm repo add tekmetric https://actekmetric.github.io/interview/
helm repo update
echo ""

# Build Helm dependencies
echo "Building Helm dependencies..."
cd $CHART_DIR
helm dependency build
cd -
echo "✓ Dependencies built"
echo ""

# Deploy with Helm
echo "Deploying backend with Helm..."
helm install backend $CHART_DIR \
  --values $CHART_DIR/values-local-kind-testing.yaml \
  --set tekmetric-common-chart.image.repository=ghcr.io/actekmetric \
  --set tekmetric-common-chart.image.tag=$IMAGE_TAG \
  --set tekmetric-common-chart.image.pullPolicy=Never \
  --wait \
  --timeout 3m \
  --debug

echo "✓ Deployment complete"
echo ""

# Verify deployment
echo "Verifying Kubernetes resources..."
echo ""
echo "=== Deployments ==="
kubectl get deployments -A
echo ""
echo "=== Pods ==="
kubectl get pods -A
echo ""
echo "=== Services ==="
kubectl get services -A
echo ""

# Wait for pod ready
echo "Waiting for pod to be ready..."
kubectl wait --for=condition=ready --timeout=120s \
  pod -l app.kubernetes.io/name=backend -n default

echo "✓ Pod is ready"
echo ""

# Check pod logs
echo "=== Pod Logs ==="
kubectl logs -l app.kubernetes.io/name=backend --tail=50 -n default
echo ""

# Port forward and test
echo "Testing application..."
kubectl port-forward service/backend 8080:8080 -n default &
PF_PID=$!
sleep 5

# Run smoke tests
if [ -f "./sre/scripts/smoke-tests.sh" ]; then
  echo "Running smoke tests..."
  chmod +x ./sre/scripts/smoke-tests.sh
  ./sre/scripts/smoke-tests.sh
else
  echo "Testing health endpoint..."
  curl -f http://localhost:8080/health || echo "Health check failed"
fi

# Cleanup port-forward
kill $PF_PID 2>/dev/null || true

echo ""
echo "=== Testing Complete ==="
echo ""
echo "Cluster is still running: $CLUSTER_NAME"
echo ""
echo "To interact with the cluster:"
echo "  kubectl get pods"
echo "  kubectl logs -l app.kubernetes.io/name=backend"
echo "  kubectl port-forward service/backend 8080:8080"
echo ""
echo "To delete the cluster:"
echo "  k3d cluster delete $CLUSTER_NAME"
echo ""

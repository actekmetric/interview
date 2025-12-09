#!/bin/bash
set -e

# Test GitHub Actions workflow locally using act
# https://github.com/nektos/act

echo "=== GitHub Actions Local Testing with act ==="
echo ""

# Check if act is installed
if ! command -v act >/dev/null 2>&1; then
  echo "act is not installed."
  echo ""
  echo "Install act with:"
  echo "  macOS: brew install act"
  echo "  Linux: curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
  echo ""
  exit 1
fi

echo "✓ act is installed"
echo ""

# Check if Podman is running
if ! podman info >/dev/null 2>&1; then
  echo "Error: Podman is not running"
  echo "Start podman machine with: podman machine start"
  exit 1
fi

echo "✓ Podman is available"
echo ""

# Configure act to use podman
# Get the socket path and ensure it's properly formatted
PODMAN_SOCKET=$(podman info --format '{{.Host.RemoteSocket.Path}}')
# Remove unix:// prefix if present, then add it back
PODMAN_SOCKET=${PODMAN_SOCKET#unix://}
export DOCKER_HOST="unix://${PODMAN_SOCKET}"
echo "Using podman at: $DOCKER_HOST"
echo ""

# Create .actrc configuration if it doesn't exist
if [ ! -f .actrc ]; then
  echo "Creating .actrc configuration..."
  cat > .actrc << 'EOF'
# Use medium-sized runner image for better compatibility
-P ubuntu-latest=catthehacker/ubuntu:act-latest
# Reuse containers for faster subsequent runs
--reuse
# Use host network for better performance
--container-options "--network host"
EOF
  echo "✓ Created .actrc"
  echo ""
fi

# Create act secrets file if needed
if [ ! -f .secrets ]; then
  echo "Creating .secrets file (add your secrets here)..."
  cat > .secrets << 'EOF'
GITHUB_TOKEN=your_github_token_here
EOF
  echo "✓ Created .secrets (edit this file to add real secrets)"
  echo ""
fi

echo "Running PR workflow with act using podman..."
echo ""
echo "Note: act will run the workflow in a podman container"
echo "This may take several minutes on first run (downloading images)"
echo ""

# Run the specific job from PR workflow
# --job: Run only the deployment-test job
# --secret-file: Use secrets from .secrets file
# --artifact-server-path: Store artifacts locally
# --env: Set environment variables to simulate PR

act pull_request \
  --job deployment-test \
  --secret-file .secrets \
  --artifact-server-path /tmp/act-artifacts \
  --workflows .github/workflows/service-backend-ci-pr-workflow.yml \
  --env GITHUB_RUN_NUMBER=999 \
  --verbose

echo ""
echo "=== act run complete ==="
echo ""
echo "Artifacts (if any) are stored in: /tmp/act-artifacts"
echo ""

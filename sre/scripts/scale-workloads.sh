#!/bin/bash
set -euo pipefail

# Script to scale Kubernetes workloads to zero or restore them
# Usage: ./scale-workloads.sh <environment> <action> [namespace]
# Actions: save, restore

ENVIRONMENT=${1:-}
ACTION=${2:-"save"}
NAMESPACE=${3:-"default"}
STATE_FILE="sre/k8s/workload-state/${ENVIRONMENT}-state.yaml"

if [ -z "$ENVIRONMENT" ]; then
  echo "Error: Environment parameter required"
  echo "Usage: $0 <environment> <save|restore> [namespace]"
  exit 1
fi

case $ACTION in
  save)
    echo "🔍 Saving current replica counts for ${ENVIRONMENT}..."

    # Get all deployments and their replica counts
    kubectl get deployments -n ${NAMESPACE} -o json | \
      jq -r '.items[] | "\(.metadata.name)=\(.spec.replicas)"' > /tmp/state.txt

    if [ ! -s /tmp/state.txt ]; then
      echo "⚠️  No deployments found in namespace ${NAMESPACE}"
      exit 0
    fi

    # Create ConfigMap with state in kube-system namespace
    kubectl create configmap workload-state-${ENVIRONMENT} \
      --from-file=state=/tmp/state.txt \
      --namespace=kube-system \
      --dry-run=client -o yaml | kubectl apply -f -

    echo "✅ State saved to ConfigMap: workload-state-${ENVIRONMENT}"

    # Also save to git for backup
    mkdir -p $(dirname ${STATE_FILE})
    cp /tmp/state.txt ${STATE_FILE}
    echo "📝 State backed up to: ${STATE_FILE}"

    # Display current state
    echo ""
    echo "Current replica counts:"
    cat /tmp/state.txt

    # Scale down to zero
    echo ""
    echo "⏬ Scaling all deployments to zero..."
    kubectl get deployments -n ${NAMESPACE} -o name | \
      xargs -I {} kubectl scale {} --replicas=0 -n ${NAMESPACE}

    echo "✅ All workloads scaled to zero"

    # Wait for pods to terminate
    echo "⏳ Waiting for pods to terminate..."
    kubectl wait --for=delete pod --all --timeout=300s -n ${NAMESPACE} || true

    echo "🎉 Environment ${ENVIRONMENT} stopped successfully"
    ;;

  restore)
    echo "🔍 Restoring replica counts for ${ENVIRONMENT}..."

    # Try to read state from ConfigMap first
    if kubectl get configmap workload-state-${ENVIRONMENT} -n kube-system &>/dev/null; then
      kubectl get configmap workload-state-${ENVIRONMENT} -n kube-system \
        -o jsonpath='{.data.state}' > /tmp/state.txt
      echo "✅ State loaded from ConfigMap"
    elif [ -f "${STATE_FILE}" ]; then
      cp ${STATE_FILE} /tmp/state.txt
      echo "✅ State loaded from file backup"
    else
      echo "❌ Error: No state found. Cannot restore workloads."
      echo "    ConfigMap not found and no backup file at ${STATE_FILE}"
      exit 1
    fi

    if [ ! -s /tmp/state.txt ]; then
      echo "⚠️  State file is empty. Nothing to restore."
      exit 0
    fi

    # Display state to be restored
    echo ""
    echo "Restoring to these replica counts:"
    cat /tmp/state.txt

    # Restore each deployment
    echo ""
    while IFS='=' read -r deployment replicas; do
      if [ -n "$deployment" ] && [ -n "$replicas" ]; then
        echo "⏫ Scaling ${deployment} to ${replicas} replicas..."
        kubectl scale deployment/${deployment} --replicas=${replicas} -n ${NAMESPACE}
      fi
    done < /tmp/state.txt

    echo "✅ All workloads restored"

    # Wait for pods to be ready
    echo "⏳ Waiting for pods to be ready (max 10 minutes)..."
    kubectl wait --for=condition=ready pod \
      --all --timeout=600s -n ${NAMESPACE} || {
      echo "⚠️  Some pods did not become ready within timeout"
      echo "Current pod status:"
      kubectl get pods -n ${NAMESPACE}
    }

    echo "🎉 Environment ${ENVIRONMENT} started successfully"
    ;;

  *)
    echo "Error: Invalid action '${ACTION}'"
    echo "Usage: $0 <environment> <save|restore> [namespace]"
    exit 1
    ;;
esac

# Cleanup
rm -f /tmp/state.txt

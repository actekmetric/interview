#!/usr/bin/env bash
set -euo pipefail

ACTION=${1:-up}
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
CHART_DIR="${REPO_ROOT}/deploy/backend/charts/backend"
ENV_DIR="${REPO_ROOT}/deploy/backend/environments/local-kind"
MANIFEST_DIR="${REPO_ROOT}/deploy/backend/manifests/local-kind"
RELEASE_NAME=${RELEASE_NAME:-backend}
NAMESPACE=${NAMESPACE:-backend-local}
KIND_CLUSTER_NAME=${KIND_CLUSTER_NAME:-backend-local}
HELM_ARGS=(-f "${ENV_DIR}/values.local.yaml" --set fullnameOverride="${RELEASE_NAME}")

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

lint_chart() {
  helm lint "${CHART_DIR}" "${HELM_ARGS[@]}"
}

render_manifests() {
  mkdir -p "${MANIFEST_DIR}"
  helm template "${RELEASE_NAME}" "${CHART_DIR}" "${HELM_ARGS[@]}" --namespace "${NAMESPACE}" > "${MANIFEST_DIR}/rendered.yaml"
  if command -v kubeconform >/dev/null 2>&1; then
    kubeconform -strict -summary "${MANIFEST_DIR}/rendered.yaml"
  else
    echo "kubeconform not installed; skipping schema validation" >&2
  fi
}

create_cluster() {
  if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
    echo "kind cluster ${KIND_CLUSTER_NAME} already exists"
    return
  fi
  kind create cluster --name "${KIND_CLUSTER_NAME}" --config "${ENV_DIR}/kind-cluster.yaml"
}

load_image() {
  if [[ -n "${KIND_IMAGE:-}" ]]; then
    kind load docker-image "${KIND_IMAGE}" --name "${KIND_CLUSTER_NAME}"
  elif [[ -n "${KIND_IMAGE_ARCHIVE:-}" && -f "${KIND_IMAGE_ARCHIVE}" ]]; then
    kind load image-archive "${KIND_IMAGE_ARCHIVE}" --name "${KIND_CLUSTER_NAME}"
  else
    echo "No KIND_IMAGE or KIND_IMAGE_ARCHIVE specified; assuming registry access" >&2
  fi
}

install_chart() {
  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
  helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" "${HELM_ARGS[@]}" --namespace "${NAMESPACE}" --create-namespace --wait
}

smoke_test() {
  kubectl rollout status deployment/"${RELEASE_NAME}" -n "${NAMESPACE}" --timeout=120s
  kubectl get service "${RELEASE_NAME}" -n "${NAMESPACE}"
}

teardown() {
  if kind get clusters | grep -q "^${KIND_CLUSTER_NAME}$"; then
    kind delete cluster --name "${KIND_CLUSTER_NAME}"
  else
    echo "kind cluster ${KIND_CLUSTER_NAME} is not present"
  fi
}

main() {
  require_cmd kind
  require_cmd helm
  require_cmd kubectl

  case "${ACTION}" in
    up)
      lint_chart
      render_manifests
      create_cluster
      load_image
      install_chart
      smoke_test
      ;;
    down)
      teardown
      ;;
    *)
      echo "Usage: $0 [up|down]" >&2
      exit 1
      ;;
  esac
}

main

# Deployment assets

This folder centralizes deployment tooling for application services. Charts live under `deploy/charts`, while environment-specific overrides and helpers are grouped under `deploy/environments` and `deploy/scripts` so new services can reuse the same workflow without duplicating directory trees.

## Layout
- `charts/<service>/` – Helm charts per service (currently `backend`).
- `environments/local-kind/` – kind cluster config plus per-service overrides for local smoke tests (e.g., `backend-values.local.yaml`).
- `manifests/local-kind/<service>/` – rendered manifests and validation output produced by the helper script (kept out of version control via `.gitkeep`).
- `scripts/` – reusable helpers for linting/rendering charts, creating the kind cluster, and deploying releases.

## Local orchestration (kind + Helm)
Use `deploy/scripts/local_up.sh` to lint the chart, render manifests, create the kind cluster, and deploy the requested service. The script defaults to the backend chart but accepts other services via `SERVICE=<name>` when additional charts are added.

### Prerequisites
- Docker (for kind)
- kind
- kubectl
- Helm
- Optional: `kubeconform` for schema validation during rendering

### Usage
```bash
# From the repository root
./deploy/scripts/local_up.sh            # deploy backend to a local kind cluster
SERVICE=backend ./deploy/scripts/local_up.sh up
SERVICE=backend ./deploy/scripts/local_up.sh down  # remove the cluster
```

Environment variables:
- `SERVICE` (default: `backend`) – selects the chart under `deploy/charts/<service>/`.
- `RELEASE_NAME` (default: value of `SERVICE`) – Helm release name; also used for resource names via `fullnameOverride`.
- `NAMESPACE` (default: `<SERVICE>-local`) – namespace for the local deployment.
- `KIND_CLUSTER_NAME` (default: `local-kind`) – kind cluster name used by the script.
- `KIND_IMAGE` or `KIND_IMAGE_ARCHIVE` – optionally load a locally built image into the cluster.

Rendered output is written to `deploy/manifests/local-kind/<service>/rendered.yaml` and can be fed into tooling such as `kubeconform` or `kube-linter`.

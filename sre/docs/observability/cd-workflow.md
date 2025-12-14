# Observability Stack CI/CD Workflow

This document explains the automated CI/CD pipeline for deploying the observability stack (Prometheus Agent, kube-state-metrics, node-exporter) to EKS clusters.

## Overview

The observability stack is deployed via GitHub Actions workflow that:
- ✅ Automatically gets AMP endpoint and IRSA role ARN from Terraform outputs
- ✅ Generates Helm values file with correct configuration
- ✅ Deploys to Kubernetes using Helm
- ✅ Verifies deployment success
- ✅ Supports manual deployment to any environment

**Workflow File**: `.github/workflows/sre-observability-cd.yml`

## Trigger Methods

### 1. Automatic Deployment (Push to Main)

Automatically deploys to **dev** environment when changes are pushed to main/master:

**Triggered by changes to:**
- `sre/helm/observability/**`
- `sre/terraform/modules/amp/**`
- `sre/terraform/modules/grafana/**`
- `.github/workflows/sre-observability-cd.yml`

**Example:**
```bash
# Make changes to Helm chart
vim sre/helm/observability/values.yaml
git add sre/helm/observability/values.yaml
git commit -m "Update observability scrape interval"
git push origin main

# Workflow triggers automatically → deploys to dev
```

### 2. Manual Deployment (workflow_dispatch)

Deploy to any environment manually via GitHub UI:

**Steps:**
1. Go to **Actions** → **Observability Stack CD**
2. Click **Run workflow**
3. Select:
   - **Environment**: dev, qa, or prod
   - **Action**: deploy, upgrade, or uninstall
4. Click **Run workflow**

## How It Works

### Step 1: Get Terraform Outputs

The workflow automatically retrieves required values from Terraform:

```bash
cd sre/terragrunt/environments/{env}/observability/amp

# Gets:
# - AMP workspace remote_write endpoint
# - Prometheus Agent IAM role ARN (for IRSA)
```

### Step 2: Generate Values File

Creates a values file with Terraform outputs:

```yaml
prometheusAgent:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123...:role/tekmetric-dev-prometheus-agent-role"
  amp:
    remoteWriteUrl: "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-abc123/..."
```

**No manual configuration needed** - values are pulled from infrastructure state.

### Step 3: Deploy with Helm

```bash
helm upgrade --install observability . \
  --namespace observability \
  --create-namespace \
  --values values-{env}-generated.yaml \
  --wait \
  --timeout 10m
```

### Step 4: Verify Deployment

```bash
# Wait for pods to be ready
kubectl wait --for=condition=ready pod --all -n observability --timeout=300s

# Check Prometheus Agent logs
kubectl logs -n observability deployment/prometheus-agent
```

## Deployment Flow

```
┌─────────────────────────┐
│  Push to main/master    │
│  (or manual trigger)    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Determine Environments  │
│ Auto: dev only          │
│ Manual: user choice     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Assume AWS Role (OIDC) │
│  Get AWS credentials    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Get Terraform Outputs   │
│ - AMP endpoint          │
│ - IRSA role ARN         │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Generate Values File   │
│  with Terraform outputs │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Configure kubectl       │
│ for target cluster      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│   Deploy with Helm      │
│   helm upgrade          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Verify Deployment      │
│  - Check pods ready     │
│  - Check logs           │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Generate Summary       │
│  in GitHub Actions UI   │
└─────────────────────────┘
```

## Environment-Specific Configuration

### Dev
- **Replicas**: 1
- **Scrape Interval**: 30s
- **Resources**: Low (256Mi memory, 100m CPU)
- **Auto-deploy**: Yes (on push to main)

### QA
- **Replicas**: 1
- **Scrape Interval**: 30s
- **Resources**: Medium (512Mi memory, 250m CPU)
- **Auto-deploy**: No (manual only)

### Prod
- **Replicas**: 2 (HA)
- **Scrape Interval**: 15s (more frequent)
- **Resources**: High (1Gi memory, 500m CPU)
- **Auto-deploy**: No (manual only)

## Prerequisites

Before the workflow can run successfully:

1. ✅ **AMP workspace deployed** (Terraform stage `6-observability/amp`)
2. ✅ **Grafana workspace deployed** (Terraform stage `7-observability/grafana`)
3. ✅ **EKS cluster running** with OIDC provider enabled
4. ✅ **GitHub secrets configured**:
   - `AWS_DEV_ROLE_ARN` / `AWS_QA_ROLE_ARN` / `AWS_PROD_ROLE_ARN`
   - `AWS_DEV_ACCOUNT_ID` / `AWS_QA_ACCOUNT_ID` / `AWS_PROD_ACCOUNT_ID`

## Workflow Jobs

### Job: determine-environments
- Decides which environments to deploy to
- Auto: dev only
- Manual: user-selected environment

### Job: deploy-dev / deploy-qa / deploy-prod
- Conditional based on determine-environments output
- Each job:
  1. Assumes AWS role via OIDC
  2. Gets Terraform outputs
  3. Configures kubectl
  4. Generates values file
  5. Deploys with Helm
  6. Verifies deployment
  7. Generates summary

## Manual Operations

### Deploy to Dev
```bash
# Via GitHub UI
Actions → Observability Stack CD → Run workflow
Environment: dev
Action: deploy
```

### Deploy to QA
```bash
# Via GitHub UI
Actions → Observability Stack CD → Run workflow
Environment: qa
Action: deploy
```

### Deploy to Prod
```bash
# Via GitHub UI
Actions → Observability Stack CD → Run workflow
Environment: prod
Action: deploy
```

### Upgrade Existing Deployment
Same as deploy - Helm will automatically upgrade if release exists.

### Uninstall
```bash
# Via GitHub UI
Actions → Observability Stack CD → Run workflow
Environment: dev (or qa/prod)
Action: uninstall
```

## Troubleshooting

### Issue: Terraform outputs not found

**Error**: `Failed to get AMP workspace endpoint`

**Cause**: AMP Terraform not applied yet

**Fix**:
1. Deploy AMP first: `/terraform apply dev 6-observability/amp`
2. Wait for completion
3. Re-run workflow

### Issue: kubectl connection failed

**Error**: `Unable to connect to the server`

**Cause**: EKS cluster not accessible or not deployed

**Fix**:
1. Verify EKS cluster exists
2. Check AWS role has EKS access permissions
3. Verify cluster name matches (`tekmetric-dev`)

### Issue: Helm deployment timeout

**Error**: `Deployment timeout after 10m`

**Cause**: Pods not starting or image pull issues

**Fix**:
1. Check pod status: `kubectl get pods -n observability`
2. Check pod events: `kubectl describe pod -n observability <pod-name>`
3. Check image pull: May need to increase timeout or check registry access

### Issue: IRSA role not working

**Error**: `403 Forbidden` when writing to AMP

**Cause**: IRSA not configured correctly

**Fix**:
1. Verify OIDC provider exists on EKS cluster
2. Check IAM role trust policy includes correct OIDC provider
3. Verify ServiceAccount annotation matches role ARN
4. Check role has `aps:RemoteWrite` permission

## Viewing Deployment Status

### Via GitHub Actions UI

1. Go to **Actions** tab
2. Click on workflow run
3. Expand job logs to see detailed output
4. Check **Summary** tab for deployment summary

### Via kubectl

```bash
# Check deployment status
kubectl get deployment,daemonset -n observability

# Check pod status
kubectl get pods -n observability

# View Prometheus Agent logs
kubectl logs -n observability deployment/prometheus-agent -f

# Check metrics are being scraped
kubectl port-forward -n observability deployment/prometheus-agent 9090:9090
# Open: http://localhost:9090/targets
```

### Via Grafana

1. Log into AWS Managed Grafana
2. Go to **Explore**
3. Query: `up{cluster="dev"}`
4. Should see metrics from all pods

## Security

### Authentication
- **AWS**: OIDC (GitHub Actions assumes AWS role, no static credentials)
- **Kubernetes**: kubectl uses AWS EKS auth (via assumed role)
- **AMP**: SigV4 via IRSA (ServiceAccount assumes IAM role)

### Permissions
- Workflow requires `AWS_*_ROLE_ARN` secrets
- IAM role needs:
  - EKS describe/access
  - Terraform state read (S3, DynamoDB)
  - Kubernetes API access

### Concurrency
- Prevents concurrent deployments to same environment
- Uses `concurrency` group with `cancel-in-progress: false`
- Safe for production deployments

## Cost Considerations

### Workflow Runtime
- **Duration**: ~3-5 minutes per environment
- **Runners**: GitHub-hosted (included in plan)
- **Cost**: Free (within GitHub Actions limits)

### Deployed Resources
- **Prometheus Agent**: Minimal cost (just compute)
- **kube-state-metrics**: Minimal cost
- **node-exporter**: Minimal cost (DaemonSet)
- **AMP ingestion**: $0.30 per million samples (main cost)

## Related Documentation

- [Phase 2 Helm Deployment Guide](./phase2-helm-deployment.md)
- [Main Observability Documentation](../OBSERVABILITY.md)
- [Helm Chart README](../../helm/observability/README.md)
- [Terraform GitOps Workflow](../github/workflows.md)

## Support

For issues with the CI/CD workflow:
1. Check workflow logs in GitHub Actions
2. Verify prerequisites are met
3. Check pod logs: `kubectl logs -n observability <pod-name>`
4. Review Terraform outputs are correct
5. Verify IAM permissions

---

**Last Updated**: 2025-12-14
**Workflow Version**: 1.0
**Automated**: Yes (dev on push, qa/prod manual)

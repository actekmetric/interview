# Observability Stack Helm Chart

Kubernetes observability stack for metrics collection and export to AWS Managed Prometheus (AMP).

## Components

- **Prometheus Agent** - Scrapes metrics and sends to AMP via remote_write
- **kube-state-metrics** - Kubernetes cluster state metrics
- **node-exporter** - Node-level system metrics

## Quick Start

```bash
# 1. Get values from Terraform outputs
cd sre/terragrunt/environments/dev/observability/amp
terragrunt output workspace_endpoint
terragrunt output prometheus_agent_role_arn

# 2. Update values file
vim values-dev.yaml
# - Set amp.remoteWriteUrl
# - Set serviceAccount.annotations.eks.amazonaws.com/role-arn

# 3. Deploy
helm upgrade --install observability . \
  --namespace observability \
  --create-namespace \
  --values values-dev.yaml

# 4. Verify
kubectl get pods -n observability
kubectl logs -n observability deployment/prometheus-agent
```

## Documentation

**Full documentation**: [sre/docs/observability/phase2-helm-deployment.md](../../docs/observability/phase2-helm-deployment.md)

**Main Observability Docs**: [sre/docs/OBSERVABILITY.md](../../docs/OBSERVABILITY.md)

**CI/CD Workflow**: [.github/workflows/sre-observability-cd.yml](../../../.github/workflows/sre-observability-cd.yml)

## Values Files

- `values-dev.yaml` - Development environment
- `values-qa.yaml` - QA environment
- `values-prod.yaml` - Production environment

## Support

For detailed installation, configuration, troubleshooting, and examples, see the full documentation linked above.

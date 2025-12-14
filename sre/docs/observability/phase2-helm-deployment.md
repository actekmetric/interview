# Observability Stack Helm Chart

Kubernetes observability stack for metrics collection and export to AWS Managed Prometheus (AMP).

## Components

This umbrella chart deploys:

1. **Prometheus Agent** - Scrapes metrics from pods and sends to AMP via remote_write
2. **kube-state-metrics** - Exposes Kubernetes cluster state metrics
3. **node-exporter** - Exposes node-level system metrics (CPU, memory, disk, network)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        EKS Cluster                           │
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   │
│  │   Backend    │   │ kube-state-  │   │     node-    │   │
│  │   Pods       │   │   metrics    │   │   exporter   │   │
│  │              │   │              │   │ (DaemonSet)  │   │
│  │ :8080        │   │ :8080        │   │ :9100        │   │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   │
│         │ scrape            │ scrape            │ scrape    │
│         │                   │                   │           │
│  ┌──────▼───────────────────▼───────────────────▼───────┐  │
│  │           Prometheus Agent (IRSA)                    │  │
│  │           :9090                                       │  │
│  └────────────────────────┬──────────────────────────────┘  │
│                           │ remote_write (SigV4)            │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            ▼
                  ┌──────────────────┐
                  │  AWS Managed     │
                  │  Prometheus      │
                  │  (AMP)           │
                  └─────────┬────────┘
                            │ query
                            ▼
                  ┌──────────────────┐
                  │  AWS Managed     │
                  │  Grafana         │
                  │  (AMG)           │
                  └──────────────────┘
```

## Prerequisites

### Phase 1: Infrastructure (Must be deployed first)
1. ✅ AMP workspace deployed (Terraform stage `6-observability/amp`)
2. ✅ AMG workspace deployed (Terraform stage `7-observability/grafana`)
3. ✅ IRSA role for Prometheus Agent created (output from AMP Terraform)

### EKS Cluster Requirements
- EKS cluster with OIDC provider enabled
- IRSA configured for service accounts
- Namespace `observability` (will be created by this chart)

## Installation

### Step 1: Get Required Values from Terraform

You need two values from the AMP Terraform deployment:

```bash
# Navigate to AMP terragrunt directory
cd sre/terragrunt/environments/dev/observability/amp

# Get AMP remote_write endpoint
terragrunt output workspace_endpoint
# Example output: https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-abc123/api/v1/remote_write

# Get Prometheus Agent IAM role ARN (for IRSA)
terragrunt output prometheus_agent_role_arn
# Example output: arn:aws:iam::123456789012:role/tekmetric-dev-prometheus-agent-role
```

### Step 2: Update Environment-Specific Values File

Edit the values file for your environment:

**For Dev:**
```bash
# Edit values-dev.yaml
vim sre/helm/observability/values-dev.yaml
```

Update these two values:
```yaml
prometheusAgent:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/tekmetric-dev-prometheus-agent-role"  # <-- Replace

  amp:
    remoteWriteUrl: "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-abc123/api/v1/remote_write"  # <-- Replace
```

### Step 3: Configure kubectl

```bash
# Configure kubectl for target cluster
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1 \
  --profile dev
```

### Step 4: Deploy Observability Stack

```bash
# From repository root
cd sre/helm/observability

# Deploy to dev
helm upgrade --install observability . \
  --namespace observability \
  --create-namespace \
  --values values-dev.yaml

# Or deploy to qa/prod
helm upgrade --install observability . \
  --namespace observability \
  --create-namespace \
  --values values-qa.yaml  # or values-prod.yaml
```

### Step 5: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n observability

# Expected output:
# NAME                                   READY   STATUS    RESTARTS   AGE
# prometheus-agent-xxxx                  1/1     Running   0          1m
# kube-state-metrics-xxxx                1/1     Running   0          1m
# node-exporter-xxxx (one per node)      1/1     Running   0          1m

# Check prometheus-agent logs
kubectl logs -n observability deployment/prometheus-agent

# Should see successful scrapes and remote_write operations

# Check metrics are being scraped
kubectl port-forward -n observability deployment/prometheus-agent 9090:9090
# Open http://localhost:9090 and check targets
```

## Configuration

### Prometheus Agent

The Prometheus Agent automatically discovers and scrapes:

1. **Pods with prometheus.io annotations**:
   ```yaml
   annotations:
     prometheus.io/scrape: "true"
     prometheus.io/port: "8080"
     prometheus.io/path: "/actuator/prometheus"
   ```

2. **kube-state-metrics**: Cluster-level metrics
3. **node-exporter**: Node-level system metrics

### Remote Write Configuration

Metrics are sent to AMP using:
- **Authentication**: AWS SigV4 (via IRSA)
- **Protocol**: HTTPS
- **Endpoint**: AMP workspace remote_write URL
- **Queue**: Configured for reliability and performance

### Scrape Intervals

- **Dev**: 30s scrape interval
- **QA**: 30s scrape interval
- **Prod**: 15s scrape interval (more frequent)

## Accessing Metrics

### Option 1: Via Grafana (Recommended)

1. Log into AWS Managed Grafana
2. AMP datasource should already be configured (from Phase 1)
3. Create dashboards or use Explore to query metrics

### Option 2: Via Prometheus Agent (Debugging)

```bash
# Port-forward to Prometheus Agent
kubectl port-forward -n observability deployment/prometheus-agent 9090:9090

# Access UI at http://localhost:9090
# Note: Prometheus Agent doesn't store data locally, only forwards to AMP
```

### Option 3: Via AMP API

```bash
# Query AMP directly (requires AWS credentials)
aws amp query-workspace \
  --workspace-id ws-abc123 \
  --query-string 'up' \
  --region us-east-1
```

## Example Queries

Once metrics are in AMP, you can query them from Grafana:

### Backend Service Metrics
```promql
# Request rate
rate(http_server_requests_seconds_count{namespace="backend-services"}[5m])

# Error rate
sum(rate(http_server_requests_seconds_count{namespace="backend-services",status=~"5.."}[5m]))
/ sum(rate(http_server_requests_seconds_count{namespace="backend-services"}[5m]))

# P95 latency
histogram_quantile(0.95,
  rate(http_server_requests_seconds_bucket{namespace="backend-services"}[5m])
)

# JVM heap usage
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100
```

### Cluster Metrics
```promql
# Node CPU usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod count by namespace
kube_pod_info

# Deployment replicas
kube_deployment_status_replicas
```

## Troubleshooting

### Prometheus Agent Not Starting

**Check logs:**
```bash
kubectl logs -n observability deployment/prometheus-agent
```

**Common issues:**
- IRSA role ARN incorrect or not set
- AMP remote_write URL incorrect
- IAM permissions missing on IRSA role

### Metrics Not Appearing in AMP

**Verify remote_write is working:**
```bash
kubectl logs -n observability deployment/prometheus-agent | grep remote_write
```

**Check for errors:**
- 403 Forbidden: IAM permissions issue
- Connection timeout: Network/security group issue
- Invalid URL: Check AMP endpoint format

**Verify IRSA is configured:**
```bash
kubectl describe serviceaccount -n observability prometheus-agent
# Should see: eks.amazonaws.com/role-arn annotation
```

### No Metrics from Backend Pods

**Verify pod annotations:**
```bash
kubectl get pods -n backend-services -o yaml | grep prometheus
```

**Should see:**
```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/actuator/prometheus"
```

**Check if Prometheus can reach the pod:**
```bash
# Port-forward to backend pod
kubectl port-forward -n backend-services deployment/backend 8080:8080

# Test metrics endpoint
curl http://localhost:8080/actuator/prometheus
```

### node-exporter Pods Not Running

**Check DaemonSet status:**
```bash
kubectl get daemonset -n observability node-exporter
```

**Common issues:**
- Node taints preventing scheduling
- Security context restrictions
- Host path permissions

## Upgrading

```bash
# Update values file with new configuration
vim values-dev.yaml

# Upgrade release
helm upgrade observability . \
  --namespace observability \
  --values values-dev.yaml

# Verify pods are updated
kubectl rollout status deployment/prometheus-agent -n observability
kubectl rollout status daemonset/node-exporter -n observability
```

## Uninstalling

```bash
# Remove Helm release
helm uninstall observability --namespace observability

# Optionally delete namespace
kubectl delete namespace observability
```

**Note:** Metrics already stored in AMP will NOT be deleted.

## Customization

### Adding Custom Scrape Configs

Edit `values.yaml` and add to `prometheusAgent.scrapeConfigs`:

```yaml
prometheusAgent:
  scrapeConfigs:
    - job_name: 'my-custom-service'
      static_configs:
        - targets: ['my-service.my-namespace.svc.cluster.local:9090']
```

### Adjusting Resources

Update resource requests/limits in environment-specific values files:

```yaml
prometheusAgent:
  resources:
    requests:
      memory: "1Gi"
      cpu: "500m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Disabling Components

```yaml
# Disable node-exporter if not needed
nodeExporter:
  enabled: false
```

## Security

### IRSA (IAM Roles for Service Accounts)

- Prometheus Agent uses IRSA to authenticate with AMP
- No AWS credentials stored in cluster
- IAM role has minimal permissions (only `aps:RemoteWrite`)
- Role trust policy limited to specific ServiceAccount

### Network Policies

Consider adding NetworkPolicies to restrict traffic:

```yaml
# Example: Only allow Prometheus Agent to scrape pods
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus-scrape
  namespace: backend-services
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: observability
```

## Cost Considerations

### AMP Costs
- **Ingestion**: $0.30 per million samples
- **Storage**: $0.03 per GB-month
- **Query**: $0.01 per million samples scanned

### Estimated Costs (per environment)
- **Dev**: ~$10-20/month (low traffic)
- **QA**: ~$20-40/month (moderate traffic)
- **Prod**: ~$50-100/month (higher traffic, more frequent scraping)

### Cost Optimization Tips
1. Adjust scrape intervals (less frequent = lower cost)
2. Use metric relabeling to drop unnecessary metrics
3. Sample high-cardinality metrics
4. Use recording rules to pre-aggregate expensive queries

## References

- [AWS Managed Prometheus Documentation](https://docs.aws.amazon.com/prometheus/)
- [Prometheus Agent Mode](https://prometheus.io/docs/prometheus/latest/feature_flags/#prometheus-agent)
- [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics)
- [node-exporter](https://github.com/prometheus/node_exporter)
- [IRSA Documentation](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Support

For issues or questions:
- Check logs: `kubectl logs -n observability <pod-name>`
- Review Prometheus Agent targets: Port-forward and access `/targets`
- Verify IAM permissions in AWS Console
- Check AMP workspace status in AWS Console

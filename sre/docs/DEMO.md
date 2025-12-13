# SRE Infrastructure - Live Demonstration Script

## Overview

This document provides a step-by-step script for demonstrating the complete SRE infrastructure implementation, covering Infrastructure as Code, CI/CD Pipeline, Kubernetes/Helm, and Observability.

**Total Duration:** ~55 minutes
- Part 1: Infrastructure as Code (15 min)
- Part 2: CI/CD Pipeline (15 min)
- Part 3: Kubernetes & Helm Charts (15 min)
- Part 4: Observability (10 min)

---

## Prerequisites Checklist

Before starting the demo, verify:

- [ ] AWS accounts configured (dev, qa, prod)
- [ ] GitHub secrets configured (AWS_*_ACCOUNT_ID, AWS_*_ROLE_ARN)
- [ ] kubectl installed and configured
- [ ] helm installed (v3.8+)
- [ ] aws CLI configured with profiles
- [ ] EKS cluster deployed (at least dev)
- [ ] Backend service deployed (or ready to deploy)
- [ ] Terminal with good font size for screen sharing
- [ ] Browser tabs pre-opened (GitHub Actions, AWS Console, etc.)

---

## Part 1: Infrastructure as Code (15 minutes)

### Objective
Demonstrate Terraform + Terragrunt infrastructure with staged deployment strategy.

### 1.1 Show Project Structure (2 min)

```bash
# Navigate to SRE directory
cd sre

# Show high-level structure
ls -la

# Expected output:
# terraform/        - Terraform modules
# terragrunt/       - Terragrunt configurations
# helm/             - Helm charts
# k8s/              - Kubernetes manifests
# scripts/          - Helper scripts
# docs/             - Documentation
```

**Talk Points:**
- Separation of concerns: modules (terraform/) vs. configurations (terragrunt/)
- Environment-specific configs in terragrunt/environments/
- Helm charts for application deployment

### 1.2 Explain Terraform Module Structure (3 min)

```bash
# Show Terraform modules
ls -la terraform/modules/

# Expected modules:
# bootstrap/     - S3 backend, OIDC, DynamoDB locks
# networking/    - VPC, subnets, NAT, security groups
# eks/           - EKS cluster + node groups
# eks-addons/    - EKS addons (VPC CNI, CoreDNS, EBS CSI)
# iam/           - GitHub OIDC + IRSA roles
# ecr/           - Container registries

# Show a module's structure
ls -la terraform/modules/networking/

# Expected files:
# main.tf          - Main resources
# variables.tf     - Input variables
# outputs.tf       - Output values
# README.md        - Module documentation
```

**Talk Points:**
- Modular architecture for reusability
- Each module is self-contained
- Outputs from one module become inputs to next (staged deployment)

### 1.3 Demonstrate Staged Deployment Approach (5 min)

```bash
# Navigate to dev environment
cd terragrunt/environments/dev/

# Show staged directories
ls -la

# Expected stages:
# 1-networking/    - Stage 1: VPC, subnets, NAT
# 2-eks-cluster/   - Stage 2: EKS cluster
# 3-iam/           - Stage 3: IRSA roles
# 4-eks-addons/    - Stage 4: EKS addons

# Show environment-specific configuration
cat account.hcl
```

**Explain Staged Deployment:**
```
Stage 1: Networking (no dependencies)
    ↓
Stage 2: EKS Cluster (needs VPC outputs)
    ↓
Stage 3: IAM (needs EKS OIDC URL)
    ↓
Stage 4: EKS Addons (needs IRSA roles)
```

**Why Staged?**
- Eliminates circular dependencies
- Granular control over deployments
- Easier troubleshooting
- Clear dependency chain

### 1.4 Show Terragrunt Configuration (2 min)

```bash
# Show root terragrunt config
cat terragrunt.hcl
```

**Key Features to Highlight:**
- Remote state configuration (S3 + DynamoDB)
- Provider generation
- Common inputs (environment, region, k8s_version)
- DRY principles

### 1.5 Show Terraform State in S3 (3 min)

```bash
# List S3 state bucket
aws s3 ls s3://tekmetric-terraform-state-us-east-1-596308305263/

# Show state file for networking stage
aws s3 ls s3://tekmetric-terraform-state-us-east-1-596308305263/environments/dev/1-networking/

# View DynamoDB lock table
aws dynamodb describe-table \
  --table-name tekmetric-terraform-locks-us-east-1-596308305263 \
  --query 'Table.TableStatus'
```

**Talk Points:**
- State stored remotely in S3
- State locking via DynamoDB
- Encrypted at rest
- Separate state per environment
- Per-module state granularity

---

## Part 2: CI/CD Pipeline (15 minutes)

### Objective
Demonstrate automated build, test, scan, and deploy pipeline.

### 2.1 Show GitHub Actions Workflows (3 min)

**Open GitHub Actions Tab:**
- Navigate to: https://github.com/YOUR_ORG/interview/actions

**Workflows to Highlight:**
1. **Backend Service CI** - Build, test, scan, publish
2. **Backend Service CD** - Deploy to EKS
3. **Terraform GitOps** - Infrastructure deployment
4. **Helm Common Chart** - Shared library chart publishing

### 2.2 Trigger Backend CI Workflow (5 min)

**Option A: Push a Small Change**
```bash
# Make a trivial change
cd backend
echo "# CI Demo" >> README.md
git add README.md
git commit -m "Trigger CI demo"
git push origin main
```

**Option B: Manual Trigger**
- Go to Actions → Backend Service CI → Run workflow

**Watch the Workflow:**
1. **Build & Test Job:**
   - Maven compilation
   - Unit test execution
   - Branch detection and environment determination
   - Version generation (format varies by branch: `-dev`, `-rc`, or no suffix)
   - Docker multi-platform build (amd64, arm64)
   - Trivy security scan
   - Push to ECR (only for deployable branches: develop, release/*, master, hotfix/*)

2. **Publish Helm Chart Job:**
   - Package Helm chart
   - Update chart version
   - Publish to S3 Helm repository

3. **Workflow Summary:**
   - Image reference
   - Chart version
   - Security scan results

### 2.3 Show Docker Image in ECR (2 min)

```bash
# List images in ECR
aws ecr describe-images \
  --repository-name backend \
  --region us-east-1 \
  --query 'imageDetails[*].[imageTags[0],imagePushedAt]' \
  --output table

# Or via AWS Console:
# Navigate to: ECR → Repositories → backend
```

**Show:**
- Multi-platform manifest (amd64, arm64)
- Image tags with semantic versioning
- Image scan findings (from Trivy)

### 2.4 Show Helm Chart in S3 (2 min)

```bash
# List Helm charts in S3
aws s3 ls s3://tekmetric-helm-charts-dev/charts/

# Show backend chart versions
aws s3 ls s3://tekmetric-helm-charts-dev/charts/ | grep backend-service
```

**Talk Points:**
- Helm charts stored in S3
- Using helm-s3 plugin
- Versioned releases
- Metadata in index.yaml

### 2.5 Show CD Workflow (3 min)

**Automatic Trigger:**
- CD workflow triggers automatically after CI completes (for deployable branches only)
- Branch-based deployment: develop → dev, release/* → qa, master → prod (manual approval)

**Manual Trigger (if needed):**
- Actions → Backend Service CD → Run workflow
- Select environment (dev/qa/prod)
- Specify image tag

**Watch Deployment:**
1. Environment determination
2. AWS authentication via OIDC
3. EKS kubeconfig update
4. Helm chart deployment
5. Smoke tests (if implemented)
6. Deployment summary

---

## Part 3: Kubernetes & Helm Charts (15 minutes)

### Objective
Demonstrate production-ready Helm charts and Kubernetes deployment.

### 3.1 Show Helm Chart Structure (3 min)

```bash
# Navigate to Helm charts
cd sre/helm/backend/

# Show chart structure
tree -L 2

# Expected structure:
# Chart.yaml           - Chart metadata
# values.yaml          - Production values
# values-dev.yaml      - Dev overrides
# templates/           - Usually empty (uses common chart)
# charts/              - Dependencies (tekmetric-common-chart)
```

**Show Chart.yaml:**
```bash
cat Chart.yaml
```

**Highlight:**
- Chart version: 0.1.0
- App version: 1.0-SNAPSHOT
- Dependency on tekmetric-common-chart (library chart)

### 3.2 Explain Common Chart Pattern (3 min)

```bash
# Show common chart
ls -la common/charts/tekmetric-common-chart/

# Show templates
ls -la common/charts/tekmetric-common-chart/templates/

# Key templates:
# deployment.yaml      - Deployment with all features
# service.yaml         - Service configuration
# hpa.yaml             - Horizontal Pod Autoscaler
# pdb.yaml             - Pod Disruption Budget
# serviceaccount.yaml  - Service account with IRSA
# ingress.yaml         - Ingress configuration
```

**Talk Points:**
- DRY principle: One common chart, many services
- Production features built-in
- Consistent deployment patterns
- Easy to add new services

### 3.3 Show Production Features in values.yaml (4 min)

```bash
# Show production values
cat values.yaml
```

**Highlight Key Features:**

1. **Resource Management:**
```yaml
resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 250m
    memory: 512Mi
```

2. **Health Probes:**
```yaml
probes:
  liveness:
    path: /actuator/health/liveness
    initialDelaySeconds: 60
  readiness:
    path: /actuator/health/readiness
    initialDelaySeconds: 30
  startup:
    path: /actuator/health/readiness
    failureThreshold: 30
```

3. **Pod Disruption Budget:**
```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

4. **Security Contexts:**
```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
```

5. **HPA (optional):**
```yaml
autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
  targetCPU: 70
```

### 3.4 Check Deployed Resources (5 min)

```bash
# Get EKS credentials
aws eks update-kubeconfig \
  --name tekmetric-dev \
  --region us-east-1

# Check nodes
kubectl get nodes

# Check namespaces
kubectl get namespaces

# Check backend deployment
kubectl get deployments -n backend-services

# Check pods
kubectl get pods -n backend-services

# Check services
kubectl get svc -n backend-services

# Detailed pod information
kubectl describe pod -n backend-services -l app=backend | head -50
```

**Show Key Details:**
- Pod status: Running
- Replicas: 1/1 (or 2/2 for prod)
- Container image tag
- Resource limits/requests
- Liveness/readiness probes
- Security contexts
- Pod annotations (Prometheus scraping)

```bash
# Show deployment details
kubectl describe deployment backend -n backend-services
```

**Highlight:**
- Rolling update strategy
- Replica count
- Pod template
- Update history

```bash
# Show deployment history
kubectl rollout history deployment/backend -n backend-services

# Show specific revision
kubectl rollout history deployment/backend -n backend-services --revision=1
```

---

## Part 4: Observability (10 minutes)

### Objective
Demonstrate metrics, logging, and observability features.

### 4.1 Access Health Endpoints (3 min)

**Option A: Via kubectl port-forward (if no ingress)**
```bash
# Port forward to backend service
kubectl port-forward -n backend-services svc/backend 8080:8080 &

# In another terminal or browser
curl http://localhost:8080/actuator/health | jq '.'

# Expected output:
{
  "status": "UP",
  "components": {
    "db": {  "status": "UP" },
    "diskSpace": { "status": "UP" },
    "livenessState": { "status": "UP" },
    "readinessState": { "status": "UP" }
  }
}
```

**Option B: Via Ingress (if enabled)**
```bash
# Get ingress URL
kubectl get ingress -n backend-services

# Test health endpoint
curl http://backend-dev.tekmetric.local/actuator/health | jq '.'
```

### 4.2 Show Available Metrics (3 min)

```bash
# List all metrics
curl http://localhost:8080/actuator/metrics | jq '.names'

# Expected output:
[
  "jvm.memory.used",
  "jvm.memory.max",
  "jvm.gc.pause",
  "http.server.requests",
  "process.uptime",
  "process.cpu.usage",
  ...
]

# Get specific metric
curl http://localhost:8080/actuator/metrics/jvm.memory.used | jq '.'

# Get HTTP request metrics
curl http://localhost:8080/actuator/metrics/http.server.requests | jq '.'
```

### 4.3 Show Prometheus Metrics (2 min)

```bash
# Get Prometheus-formatted metrics
curl http://localhost:8080/actuator/prometheus

# Filter for JVM metrics
curl http://localhost:8080/actuator/prometheus | grep "^jvm_memory"

# Filter for HTTP metrics
curl http://localhost:8080/actuator/prometheus | grep "^http_server_requests"

# Example output:
# jvm_memory_used_bytes{area="heap",id="G1 Eden Space",} 25165824
# jvm_memory_max_bytes{area="heap",id="G1 Old Gen",} 268435456
# http_server_requests_seconds_count{method="GET",status="200",uri="/api/welcome",} 42
# http_server_requests_seconds_sum{method="GET",status="200",uri="/api/welcome",} 0.123
```

**Talk Points:**
- Prometheus-compatible format
- Metrics ready for scraping
- Pod annotations configured (prometheus.io/scrape, port, path)
- No Prometheus deployed yet, but framework ready

### 4.4 Show Application Logs (2 min)

```bash
# View real-time logs
kubectl logs -f deployment/backend -n backend-services

# Last 50 lines
kubectl logs --tail=50 deployment/backend -n backend-services

# Logs from all pods
kubectl logs -l app=backend -n backend-services --all-containers=true
```

**Talk Points:**
- Application logs via standard output
- Kubernetes captures container logs
- EKS forwards to CloudWatch
- Can be aggregated with Loki/ELK

### 4.5 Explain OpenTelemetry Integration (bonus if time)

```bash
# Show Dockerfile with OTEL agent
cat backend/docker/Dockerfile | grep -A5 "opentelemetry"

# Show Helm values OTEL config
cat sre/helm/backend/values-dev.yaml | grep -A10 "observability"
```

**Talk Points:**
- OTEL Java agent pre-installed
- Automatic instrumentation for HTTP, JDBC, etc.
- Ready to send traces when collector deployed
- No code changes needed

---

## Verification Commands

### Quick Health Check
```bash
# All-in-one health check script
cat << 'EOF' > /tmp/health-check.sh
#!/bin/bash
echo "=== EKS Cluster ==="
kubectl get nodes

echo -e "\n=== Backend Deployment ==="
kubectl get deployment backend -n backend-services

echo -e "\n=== Backend Pods ==="
kubectl get pods -n backend-services

echo -e "\n=== Backend Service ==="
kubectl get svc backend -n backend-services

echo -e "\n=== Health Endpoint ==="
kubectl port-forward -n backend-services svc/backend 8080:8080 &
PF_PID=$!
sleep 2
curl -s http://localhost:8080/actuator/health | jq '.status'
kill $PF_PID

echo -e "\n✅ Health check complete"
EOF

chmod +x /tmp/health-check.sh
/tmp/health-check.sh
```

### Load Test (Optional Demo)
```bash
# Simple load test using hey (if installed)
hey -n 1000 -c 50 http://localhost:8080/api/welcome

# Or using Apache Bench
ab -n 1000 -c 50 http://localhost:8080/api/welcome

# Watch metrics during load
watch -n 1 'curl -s http://localhost:8080/actuator/metrics/http.server.requests | jq ".measurements[0].value"'
```

---

## Troubleshooting During Demo

### Pod Not Running
```bash
# Check pod status
kubectl get pods -n backend-services

# Describe pod for events
kubectl describe pod <pod-name> -n backend-services

# Check logs
kubectl logs <pod-name> -n backend-services

# Common issues:
# - Image pull errors (check ECR permissions)
# - Insufficient resources (check node capacity)
# - Startup probe failing (check actuator endpoints)
```

### Cannot Access Endpoints
```bash
# Verify service exists
kubectl get svc backend -n backend-services

# Check endpoints
kubectl get endpoints backend -n backend-services

# Test from within cluster
kubectl run curl --image=curlimages/curl -i --rm --restart=Never -- \
  curl http://backend.backend-services:8080/actuator/health
```

### Ingress Not Working
```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resource
kubectl get ingress -n backend-services

# Describe ingress for events
kubectl describe ingress backend -n backend-services

# Fallback: Use port-forward
kubectl port-forward -n backend-services svc/backend 8080:8080
```

---

## Demo Flow Summary

**Part 1: Infrastructure as Code (15 min)**
1. Show project structure
2. Explain Terraform modules
3. Demonstrate staged deployment
4. Show terragrunt configuration
5. Verify state in S3

**Part 2: CI/CD Pipeline (15 min)**
1. Show GitHub Actions workflows
2. Trigger backend CI workflow
3. Show Docker image in ECR
4. Show Helm chart in S3
5. Explain CD workflow

**Part 3: Kubernetes & Helm Charts (15 min)**
1. Show Helm chart structure
2. Explain common chart pattern
3. Highlight production features
4. Check deployed resources
5. Show deployment history

**Part 4: Observability (10 min)**
1. Access health endpoints
2. Show available metrics
3. Show Prometheus metrics
4. View application logs
5. Explain OpenTelemetry integration

---

## Key Talking Points

### Why This Architecture?

**Staged Deployment:**
- Eliminates circular dependencies
- Granular control
- Easier troubleshooting

**GitHub OIDC:**
- No long-lived credentials
- Better security
- Automatic key rotation

**Multi-Account Setup:**
- Environment isolation
- Cost tracking
- Independent deployments

**Helm Library Chart:**
- DRY principle
- Consistent deployments
- Production features built-in

**OpenTelemetry:**
- Vendor-neutral observability
- Automatic instrumentation
- Future-proof architecture

### Production-Ready Features

**High Availability:**
- Pod Disruption Budget
- Pod anti-affinity rules
- Multiple replicas (prod)
- Rolling updates (zero downtime)

**Security:**
- Non-root containers
- Dropped capabilities
- Read-only root filesystem (where possible)
- IRSA for pod-level IAM permissions

**Observability:**
- Health probes for self-healing
- Metrics exposed for monitoring
- Structured logging ready
- Tracing instrumentation integrated

**Resource Management:**
- CPU/memory limits and requests
- HPA for auto-scaling
- Resource quotas
- Cost optimization (start/stop workflows)

---

## Post-Demo Questions & Answers

### Q: How do you handle secrets?
**A:** Currently using Kubernetes secrets. Would recommend:
- AWS Secrets Manager with IRSA
- External Secrets Operator
- Sealed Secrets for GitOps

### Q: How do you handle database migrations?
**A:** Using H2 in-memory for demo. For production:
- Flyway/Liquibase for schema management
- Init containers for migrations
- Separate migration job before deployment

### Q: What about disaster recovery?
**A:** Infrastructure as Code provides recovery:
- State stored in S3 (versioned)
- Can recreate entire environment from code
- Velero for K8s backup/restore
- Database backups (RDS automated backups)

### Q: How do you handle configuration across environments?
**A:** Multiple layers:
- Terragrunt for infrastructure config
- Helm values files per environment
- Kubernetes ConfigMaps/Secrets
- Environment variables

### Q: What's next for this infrastructure?
**A:**
1. Deploy monitoring stack (Prometheus + Grafana)
2. Add distributed tracing backend (Jaeger/Tempo)
3. Implement GitOps with ArgoCD
4. Add more environments (staging)
5. Implement blue/green or canary deployments
6. Add service mesh (Istio/Linkerd)

---

## Success Criteria

Demo is successful if you can show:
- [ ] Infrastructure deployed via Terraform/Terragrunt
- [ ] CI/CD pipeline automatically building and deploying
- [ ] Backend service running in EKS
- [ ] Health endpoints responding
- [ ] Metrics available for collection
- [ ] Logs accessible via kubectl
- [ ] Clear explanation of architecture decisions
- [ ] Production-ready features highlighted

---

## Notes

- Practice the demo at least once before interview
- Have backup plans (port-forward vs ingress)
- Keep terminal font large for screen sharing
- Pre-open browser tabs to save time
- Have troubleshooting commands ready
- Focus on architecture and decisions, not just "what" but "why"
- Be prepared to dive deeper into any section
- Time management: Stick to 15/15/15/10 split
- Leave time for questions

---

## Quick Reference Commands

```bash
# EKS access
aws eks update-kubeconfig --name tekmetric-dev --region us-east-1

# Pod status
kubectl get pods -n backend-services

# Logs
kubectl logs -f deployment/backend -n backend-services

# Port forward
kubectl port-forward -n backend-services svc/backend 8080:8080

# Health check
curl http://localhost:8080/actuator/health

# Metrics
curl http://localhost:8080/actuator/prometheus | grep jvm_memory

# ECR images
aws ecr describe-images --repository-name backend --region us-east-1

# S3 Helm charts
aws s3 ls s3://tekmetric-helm-charts-dev/charts/

# Deployment history
kubectl rollout history deployment/backend -n backend-services
```

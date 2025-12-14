# Helm Production Features Guide

## Related Documentation

- **Quick Overview:** [../PRESENTATION.md](../PRESENTATION.md) - High-level Helm architecture (Slide 5)
- **Architecture Context:** [../ARCHITECTURE.md](../ARCHITECTURE.md) - Complete Kubernetes and Helm architecture
- **Helm Chart Source:** [../../helm/backend/](../../helm/backend/) - Backend service Helm chart
- **Common Chart:** [../../helm/common/charts/tekmetric-common-chart/](../../helm/common/charts/tekmetric-common-chart/) - Library chart templates

---

## Overview

This document provides complete reference for production-ready features built into the `tekmetric-common-chart` Helm library chart. All examples use values from the backend service deployment.

**Chart Architecture:**
```
helm/
├── backend/                    # Application chart
│   ├── Chart.yaml             # Depends on tekmetric-common-chart
│   ├── values.yaml            # Production defaults
│   └── values-dev.yaml        # Dev overrides
└── common/
    └── charts/tekmetric-common-chart/    # Library chart
        ├── templates/         # Reusable templates
        │   ├── deployment.yaml
        │   ├── service.yaml
        │   ├── hpa.yaml
        │   ├── pdb.yaml
        │   ├── serviceaccount.yaml
        │   └── ingress.yaml
        └── values.yaml        # Default values
```

---

## 1. Resource Management

### Configuration

```yaml
resources:
  limits:
    cpu: 1000m      # Maximum CPU (1 core)
    memory: 1Gi     # Maximum memory
  requests:
    cpu: 250m       # Reserved CPU (0.25 cores)
    memory: 512Mi   # Reserved memory
```

### Benefits

- **Prevents Resource Exhaustion:** Limits prevent pods from consuming all node resources
- **Enables Proper Scheduling:** Kubernetes scheduler uses requests to place pods on nodes with sufficient capacity
- **Supports HPA Decisions:** Horizontal Pod Autoscaler uses CPU/memory metrics to scale
- **Cost Optimization:** Right-sizing prevents over-provisioning

### Best Practices

**Requests:**
- Set based on actual usage patterns (use `kubectl top pods` to measure)
- Should cover baseline usage + small buffer
- Too low: Pods may be scheduled on overcommitted nodes
- Too high: Inefficient resource utilization

**Limits:**
- Should be 2-4x requests for applications with variable load
- Prevents single pod from impacting others
- CPU: Pods are throttled when exceeding limit
- Memory: Pods are OOMKilled when exceeding limit

**Example Tuning:**
```yaml
# Development (low resources)
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits: { cpu: 500m, memory: 512Mi }

# Production (higher resources)
resources:
  requests: { cpu: 250m, memory: 512Mi }
  limits: { cpu: 1000m, memory: 1Gi }

# High-traffic production (even more)
resources:
  requests: { cpu: 500m, memory: 1Gi }
  limits: { cpu: 2000m, memory: 2Gi }
```

---

## 2. Health Probes

### Configuration

```yaml
probes:
  liveness:
    enabled: true
    path: /actuator/health/liveness
    port: http
    initialDelaySeconds: 60    # Wait 60s before first check
    periodSeconds: 10           # Check every 10s
    timeoutSeconds: 5           # 5s timeout per check
    failureThreshold: 3         # Restart after 3 failures
    successThreshold: 1         # Healthy after 1 success

  readiness:
    enabled: true
    path: /actuator/health/readiness
    port: http
    initialDelaySeconds: 30    # Wait 30s before first check
    periodSeconds: 10           # Check every 10s
    timeoutSeconds: 5           # 5s timeout
    failureThreshold: 3         # Remove from service after 3 failures
    successThreshold: 1         # Ready after 1 success

  startup:
    enabled: true
    path: /actuator/health/readiness
    port: http
    initialDelaySeconds: 0     # Start checking immediately
    periodSeconds: 10           # Check every 10s
    timeoutSeconds: 5           # 5s timeout
    failureThreshold: 30        # Allow 30 failures (5 minutes total)
    successThreshold: 1         # Started after 1 success
```

### Probe Types Explained

**Liveness Probe:**
- **Purpose:** Detect if application is running but stuck (deadlock, infinite loop)
- **Action:** Restart container if probe fails
- **Use Case:** Application is alive but unable to make progress
- **Example:** Thread deadlock, memory leak causing unresponsiveness

**Readiness Probe:**
- **Purpose:** Detect if application is ready to serve traffic
- **Action:** Remove pod from service endpoints (no restart)
- **Use Case:** Application starting up, temporarily overloaded, dependency unavailable
- **Example:** Database connection initializing, cache warming up

**Startup Probe:**
- **Purpose:** Allow applications with slow startup without triggering liveness probe
- **Action:** Disable liveness/readiness until startup succeeds
- **Use Case:** Applications that take a long time to start (1+ minutes)
- **Example:** Large Spring Boot application, data preloading, schema migrations

### Best Practices

1. **Always enable startup probe** for applications with initialization >30s
2. **Set initialDelaySeconds conservatively** - Better to wait longer than restart prematurely
3. **Use different paths** for liveness vs readiness if possible
4. **Keep timeouts reasonable** - Network hiccups happen
5. **Test probes locally** before deploying: `curl http://localhost:8080/actuator/health/liveness`

### Spring Boot Actuator Integration

The backend service uses Spring Boot Actuator health endpoints:

```properties
# application.properties
management.endpoints.web.exposure.include=health,metrics,prometheus
management.endpoint.health.probes.enabled=true
management.health.livenessState.enabled=true
management.health.readinessState.enabled=true
```

**Liveness endpoint:** `/actuator/health/liveness`
- Returns 200 if application is alive
- Returns 503 if application is broken

**Readiness endpoint:** `/actuator/health/readiness`
- Returns 200 if application can serve traffic
- Returns 503 if application dependencies are unavailable

---

## 3. High Availability

### Pod Disruption Budget

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1    # Always keep at least 1 pod running
  # OR
  # maxUnavailable: 1  # Never have more than 1 pod down
```

**Purpose:** Prevent voluntary disruptions from taking down all pods simultaneously

**Voluntary Disruptions:**
- Node draining for maintenance
- Cluster autoscaler scaling down
- Deployment rollouts
- Manual pod deletions

**Benefits:**
- Ensures minimum availability during updates
- Prevents "all pods down" scenarios
- Required for production zero-downtime deployments

**Configuration Strategies:**
```yaml
# Option 1: Minimum available (recommended)
minAvailable: 1          # At least 1 pod always running
minAvailable: "50%"      # At least 50% of pods running

# Option 2: Maximum unavailable
maxUnavailable: 1        # At most 1 pod can be down
maxUnavailable: "25%"    # At most 25% of pods can be down
```

### Pod Anti-Affinity

```yaml
affinity:
  enabled: true
  type: soft         # Prefer spreading across nodes (soft)
  # type: hard       # Require spreading across nodes (hard)
```

**Purpose:** Spread pods across different nodes for redundancy

**Soft vs Hard:**
- **Soft (preferred):** Try to spread, but allow multiple pods per node if necessary
- **Hard (required):** Never schedule multiple pods on same node (may cause scheduling failures)

**Recommendation:** Use `soft` for most cases. Use `hard` only for critical services with sufficient node capacity.

---

## 4. Zero-Downtime Deployments

### Rolling Update Strategy

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1           # Can create 1 extra pod during update
    maxUnavailable: 0     # Never allow 0 pods to be unavailable
```

**How It Works:**
1. Create new pod with new version (`maxSurge: 1`)
2. Wait for new pod to become ready (readiness probe)
3. Terminate old pod
4. Repeat until all pods updated

**Parameters:**
- `maxSurge`: Extra pods allowed during update (capacity overhead)
- `maxUnavailable`: How many pods can be down during update

**Zero-Downtime Configuration:**
```yaml
maxSurge: 1              # Always have extra capacity during rollout
maxUnavailable: 0        # Never reduce capacity below desired replicas
```

**Fast Rollout Configuration:**
```yaml
maxSurge: 100%           # Double capacity during rollout (expensive!)
maxUnavailable: 0        # No downtime
```

### Graceful Shutdown

```yaml
terminationGracePeriodSeconds: 30   # Wait 30s for graceful shutdown
```

**Shutdown Sequence:**
1. Pod receives SIGTERM signal
2. Application begins graceful shutdown (finish current requests)
3. Kubernetes waits `terminationGracePeriodSeconds`
4. If still running, Kubernetes sends SIGKILL (force kill)

**Best Practices:**
- Set to 2-3x your longest request timeout
- For long-running jobs: Set higher (60-120s)
- For quick APIs: 30s is sufficient

---

## 5. Security

### Pod Security Context

```yaml
podSecurityContext:
  runAsNonRoot: true     # Prevent running as root
  runAsUser: 1000        # Run as UID 1000
  runAsGroup: 1000       # Run as GID 1000
  fsGroup: 1000          # Filesystem group ownership
  seccompProfile:
    type: RuntimeDefault # Use runtime default seccomp profile
```

**Security Benefits:**
- Prevents privilege escalation attacks
- Limits damage if container is compromised
- Follows principle of least privilege

### Container Security Context

```yaml
securityContext:
  allowPrivilegeEscalation: false   # Prevent privilege escalation
  readOnlyRootFilesystem: false     # Allow writes (Spring Boot needs /tmp)
  runAsNonRoot: true                # Don't run as root
  capabilities:
    drop:
      - ALL                         # Drop all Linux capabilities
```

**Capabilities Explained:**
- Linux capabilities provide fine-grained permissions
- Dropping `ALL` removes all unnecessary permissions
- Add back specific capabilities only if needed (e.g., `NET_BIND_SERVICE` for port <1024)

### Read-Only Root Filesystem

**Ideal Configuration:**
```yaml
readOnlyRootFilesystem: true
volumeMounts:
  - name: tmp
    mountPath: /tmp      # Writable tmpfs for temporary files
```

**Why It Matters:**
- Prevents malware from modifying application files
- Reduces attack surface
- Makes container immutable

**Note:** Spring Boot requires write access to `/tmp` for temporary files. Mount tmpfs volume if using read-only root.

---

## 6. Autoscaling (HPA)

### Configuration

```yaml
autoscaling:
  enabled: false        # Enable for production
  minReplicas: 2        # Minimum pods (never scale below this)
  maxReplicas: 10       # Maximum pods (never scale above this)
  targetCPUUtilizationPercentage: 70      # Scale when CPU > 70%
  targetMemoryUtilizationPercentage: 80   # Scale when memory > 80%
```

### How HPA Works

1. **Metrics Server** collects CPU/memory metrics from pods
2. **HPA Controller** checks metrics every 15s (default)
3. **Scaling Decision:**
   - Current metric > target → Scale up
   - Current metric < target → Scale down
4. **Cooldown Periods:**
   - Scale up: Immediate (no cooldown)
   - Scale down: 5 minutes (prevents flapping)

### Scaling Formula

```
desiredReplicas = ceil(currentReplicas * (currentMetricValue / targetMetricValue))
```

**Example:**
- Current: 3 replicas, 85% CPU
- Target: 70% CPU
- Calculation: `ceil(3 * (85 / 70)) = ceil(3.64) = 4 replicas`

### Best Practices

1. **Set resource requests:** HPA uses percentage of requests, not limits
2. **Start with CPU-based scaling:** Memory-based scaling is trickier (memory doesn't decrease easily)
3. **Set min replicas ≥ 2:** For high availability
4. **Set max replicas conservatively:** Prevent runaway scaling costs
5. **Monitor scaling events:** `kubectl get hpa` and `kubectl describe hpa`

### Custom Metrics (Advanced)

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: "1000"   # Scale at 1000 req/s per pod
```

---

## 7. IRSA (IAM Roles for Service Accounts)

### Configuration

```yaml
serviceAccount:
  create: true
  name: backend-sa
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/backend-irsa-role"
```

### How IRSA Works

1. **ServiceAccount** created with IAM role annotation
2. **EKS Webhook** injects AWS credentials into pod
3. **AWS SDK** automatically uses injected credentials
4. **Temporary credentials** rotated every 1 hour

**Architecture:**
```
Pod → ServiceAccount → IAM Role → AWS Services
```

### Benefits

- **No credentials in code** - SDK automatically uses IRSA credentials
- **Automatic rotation** - Credentials expire and refresh automatically
- **Pod-level granularity** - Different pods can have different IAM permissions
- **Audit trail** - CloudTrail logs show which pod/service account made AWS API calls

### IAM Trust Policy (Terraform)

```hcl
data "aws_iam_policy_document" "irsa_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${var.account_id}:oidc-provider/${var.oidc_provider}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:backend-services:backend-sa"]
    }
  }
}
```

### Example IAM Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/my-table"
    }
  ]
}
```

### Using IRSA in Application

**No code changes needed!** AWS SDK automatically detects and uses IRSA credentials:

```java
// Java AWS SDK v2 - automatic IRSA detection
S3Client s3 = S3Client.builder()
    .region(Region.US_EAST_1)
    .build();  // Credentials loaded automatically via IRSA

// DynamoDB client - also automatic
DynamoDbClient dynamodb = DynamoDbClient.builder()
    .region(Region.US_EAST_1)
    .build();
```

---

## 8. Additional Production Features

### Ingress (Optional)

```yaml
ingress:
  enabled: false      # Enable if using ingress controller
  className: nginx    # nginx, alb, traefik, etc.
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com
```

### Service Configuration

```yaml
service:
  type: ClusterIP      # ClusterIP, NodePort, LoadBalancer
  port: 8080          # Service port
  targetPort: http    # Container port (named port from deployment)
  annotations: {}     # Cloud provider specific annotations
```

### Environment Variables

```yaml
env:
  - name: SPRING_PROFILES_ACTIVE
    value: "production"
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url
```

### ConfigMaps and Secrets

```yaml
envFrom:
  - configMapRef:
      name: backend-config
  - secretRef:
      name: backend-secrets
```

---

## Verification Commands

### Check Resources

```bash
# View resource requests/limits
kubectl describe deployment backend -n backend-services | grep -A 5 "Limits\|Requests"

# Check actual resource usage
kubectl top pods -n backend-services

# Compare usage vs limits
kubectl top pods -n backend-services --no-headers | awk '{print $1, $2, $3}'
```

### Check Health Probes

```bash
# View probe configuration
kubectl describe deployment backend -n backend-services | grep -A 10 "Liveness\|Readiness\|Startup"

# Test probes manually
kubectl port-forward -n backend-services svc/backend 8080:8080
curl http://localhost:8080/actuator/health/liveness
curl http://localhost:8080/actuator/health/readiness
```

### Check PDB

```bash
# View PDB status
kubectl get pdb -n backend-services
kubectl describe pdb backend -n backend-services

# Check during disruption
kubectl drain <node-name> --ignore-daemonsets
kubectl get pdb -n backend-services   # Should show disruptions allowed
```

### Check HPA

```bash
# View HPA status
kubectl get hpa -n backend-services
kubectl describe hpa backend -n backend-services

# Watch scaling events
kubectl get hpa backend -n backend-services --watch

# View scaling history
kubectl describe hpa backend -n backend-services | grep -A 10 Events
```

### Check IRSA

```bash
# View service account annotations
kubectl describe sa backend-sa -n backend-services

# Check pod environment (IRSA injects AWS_* variables)
kubectl exec -n backend-services deployment/backend -- env | grep AWS

# Test AWS API access from pod
kubectl exec -n backend-services deployment/backend -- aws sts get-caller-identity
```

---

## Troubleshooting

### Pod Not Starting

**Check startup probe:**
```bash
kubectl describe pod <pod-name> -n backend-services | grep -A 5 "Startup"
```

**Fix:** Increase `failureThreshold` or `initialDelaySeconds`

### Pod Restarting Frequently

**Check liveness probe:**
```bash
kubectl logs <pod-name> -n backend-services --previous
kubectl describe pod <pod-name> -n backend-services | grep -A 5 "Liveness"
```

**Fix:** Increase `initialDelaySeconds` or `timeoutSeconds`

### OOMKilled Errors

**Check memory limits:**
```bash
kubectl describe pod <pod-name> -n backend-services | grep -i oom
```

**Fix:** Increase memory limits, or investigate memory leak

### HPA Not Scaling

**Check metrics server:**
```bash
kubectl top nodes
kubectl top pods -n backend-services
```

**Fix:** Install metrics-server if not present

### IRSA Not Working

**Check service account:**
```bash
kubectl describe sa backend-sa -n backend-services
```

**Verify IAM role trust policy includes correct OIDC provider**

---

## References

- [Kubernetes Best Practices (Google Cloud)](https://cloud.google.com/blog/products/containers-kubernetes/your-guide-kubernetes-best-practices)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Production Checklist](https://learnk8s.io/production-best-practices)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [IAM Roles for Service Accounts (IRSA)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

---

**Last Updated:** 2025-12-14
**Chart Version:** tekmetric-common-chart v0.1.0

# Backend Service Observability Integration

This document explains how the backend service integrates with the observability stack (Prometheus Agent, kube-state-metrics, node-exporter) for metrics collection.

## Overview

The backend service is a Spring Boot application that exposes Prometheus metrics via the `/actuator/prometheus` endpoint. The Prometheus Agent automatically discovers and scrapes these metrics using Kubernetes service discovery.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                       EKS Cluster                                │
│                                                                  │
│  ┌──────────────────────────────────────────┐                  │
│  │  Backend Service Pods                     │                  │
│  │  (namespace: backend-services)            │                  │
│  │                                           │                  │
│  │  Annotations:                             │                  │
│  │    prometheus.io/scrape: "true"           │                  │
│  │    prometheus.io/port: "8080"             │                  │
│  │    prometheus.io/path: "/actuator/       │                  │
│  │                         prometheus"       │                  │
│  │                                           │                  │
│  │  Exposes metrics at:                      │                  │
│  │    http://pod-ip:8080/actuator/prometheus│                  │
│  └─────────────────┬─────────────────────────┘                  │
│                    │                                             │
│                    │ scrape every 30s (dev) / 15s (prod)        │
│                    ▼                                             │
│  ┌─────────────────────────────────────────┐                   │
│  │  Prometheus Agent                        │                   │
│  │  (namespace: observability)              │                   │
│  │                                          │                   │
│  │  - Service Discovery (kubernetes_sd)     │                   │
│  │  - Filters by prometheus.io/scrape=true │                   │
│  │  - Sends to AMP via remote_write        │                   │
│  └─────────────────┬─────────────────────────┘                  │
│                    │                                             │
└────────────────────┼─────────────────────────────────────────────┘
                     │ remote_write (SigV4)
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

## Prometheus Annotations

The backend service pods use standard Prometheus annotations for service discovery:

```yaml
podAnnotations:
  prometheus.io/scrape: "true"        # Enable scraping
  prometheus.io/port: "8080"          # Port to scrape
  prometheus.io/path: "/actuator/prometheus"  # Metrics endpoint path
```

These annotations are configured in the Helm chart values files:
- `sre/helm/backend/values.yaml` - Base configuration
- `sre/helm/backend/values-dev.yaml` - Dev overrides
- `sre/helm/backend/values-qa.yaml` - QA overrides
- `sre/helm/backend/values-prod.yaml` - Production overrides

## Metrics Endpoint

The backend service exposes Prometheus metrics at:

```
http://<pod-ip>:8080/actuator/prometheus
```

This endpoint is provided by Spring Boot Actuator with the Micrometer Prometheus registry.

### Sample Metrics Exposed

```prometheus
# JVM metrics
jvm_memory_used_bytes{area="heap",id="PS Eden Space"} 1.25829120E8
jvm_gc_pause_seconds_count{action="end of minor GC",cause="Allocation Failure"} 42.0
jvm_threads_live_threads 25.0

# Application metrics
http_server_requests_seconds_count{method="GET",status="200",uri="/api/welcome"} 156.0
http_server_requests_seconds_sum{method="GET",status="200",uri="/api/welcome"} 2.345
http_server_requests_seconds_max{method="GET",status="200",uri="/api/welcome"} 0.089

# System metrics
process_cpu_usage 0.15
system_cpu_usage 0.45
```

## Automatic Service Discovery

The Prometheus Agent uses Kubernetes service discovery to find pods with the `prometheus.io/scrape: "true"` annotation.

**Prometheus Agent Configuration** (from `sre/helm/observability/templates/prometheus-agent/configmap.yaml`):

```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # Only scrape pods with prometheus.io/scrape=true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true

      # Use custom scrape path if specified
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)

      # Use custom scrape port if specified
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
```

## Environment-Specific Configuration

### Dev Environment
- **Scrape Interval**: 30 seconds
- **Replicas**: 1 backend pod
- **Resources**: 256Mi memory, 100m CPU
- **Namespace**: `backend-services`

### QA Environment
- **Scrape Interval**: 30 seconds
- **Replicas**: 2 backend pods
- **Resources**: 512Mi memory, 250m CPU
- **Namespace**: `backend-services`

### Production Environment
- **Scrape Interval**: 15 seconds (more frequent)
- **Replicas**: 3 backend pods minimum (HA)
- **Resources**: 1Gi memory, 500m CPU
- **Namespace**: `backend-services`

## Verifying Metrics Collection

### 1. Check Backend Metrics Endpoint

```bash
# Port-forward to backend pod
kubectl port-forward -n backend-services deployment/backend 8080:8080

# Curl metrics endpoint
curl http://localhost:8080/actuator/prometheus

# Should see Prometheus metrics in text format
```

### 2. Check Prometheus Agent Targets

```bash
# Port-forward to Prometheus Agent
kubectl port-forward -n observability deployment/prometheus-agent 9090:9090

# Open browser: http://localhost:9090/targets
# Look for job "kubernetes-pods"
# Backend pods should be listed and "UP"
```

### 3. Query Metrics in Grafana

```bash
# Log into AWS Managed Grafana
# Go to Explore, select AMP datasource

# Query backend metrics:
http_server_requests_seconds_count{namespace="backend-services"}

# Should see metrics from all backend pods
```

## Common Metrics Queries

### Request Rate
```promql
# Requests per second
rate(http_server_requests_seconds_count{namespace="backend-services"}[5m])
```

### Error Rate
```promql
# 5xx error rate
sum(rate(http_server_requests_seconds_count{namespace="backend-services",status=~"5.."}[5m]))
/
sum(rate(http_server_requests_seconds_count{namespace="backend-services"}[5m]))
* 100
```

### Latency (P95, P99)
```promql
# P95 latency
histogram_quantile(0.95,
  sum(rate(http_server_requests_seconds_bucket{namespace="backend-services"}[5m])) by (le)
)

# P99 latency
histogram_quantile(0.99,
  sum(rate(http_server_requests_seconds_bucket{namespace="backend-services"}[5m])) by (le)
)
```

### JVM Memory Usage
```promql
# Heap usage percentage
jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100
```

### GC Frequency
```promql
# GC pause frequency
rate(jvm_gc_pause_seconds_count[5m])
```

### Active Threads
```promql
# Thread count
jvm_threads_live_threads{namespace="backend-services"}
```

## Troubleshooting

### Metrics Not Appearing

**1. Check pod annotations:**
```bash
kubectl get pods -n backend-services -o yaml | grep -A3 prometheus.io
```

Should see:
```yaml
prometheus.io/scrape: "true"
prometheus.io/port: "8080"
prometheus.io/path: "/actuator/prometheus"
```

**2. Verify metrics endpoint is accessible:**
```bash
kubectl exec -n backend-services deployment/backend -- curl localhost:8080/actuator/prometheus
```

Should return Prometheus metrics.

**3. Check Prometheus Agent logs:**
```bash
kubectl logs -n observability deployment/prometheus-agent | grep backend
```

Look for successful scrapes or errors.

**4. Check Prometheus Agent targets:**
```bash
kubectl port-forward -n observability deployment/prometheus-agent 9090:9090
```

Open http://localhost:9090/targets and find backend pods under "kubernetes-pods" job.

### Metrics Endpoint Returns 404

**Possible causes:**
- Spring Boot Actuator not enabled
- Micrometer Prometheus registry not configured
- Incorrect path annotation

**Fix:** Ensure `pom.xml` or `build.gradle` includes:
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

And `application.yaml`:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
```

### High Cardinality Issues

If metrics are causing high cardinality (too many unique label combinations):

**Solutions:**
1. Use metric relabeling in Prometheus to drop labels
2. Aggregate metrics before remote_write
3. Sample high-cardinality metrics
4. Use recording rules for expensive queries

## Cost Optimization

### AMP Ingestion Costs

- **Pricing**: $0.30 per million samples ingested
- **Dev**: ~$5-10/month (1 pod, 30s scrape interval)
- **QA**: ~$10-20/month (2 pods, 30s scrape interval)
- **Prod**: ~$30-50/month (3+ pods, 15s scrape interval)

### Reducing Costs

1. **Increase scrape interval** (less frequent = fewer samples)
2. **Drop unnecessary metrics** via relabeling
3. **Use recording rules** to pre-aggregate expensive queries
4. **Sample high-cardinality metrics** instead of collecting all

## Next Steps

### Phase 4: Grafana Dashboards (Optional)

Create Grafana dashboards for:
- Backend service overview (requests, errors, latency)
- JVM metrics (heap, GC, threads)
- System metrics (CPU, memory, network)

### Phase 5: Alerting (Optional)

Configure alert rules in AMP for:
- High error rate (>5% 5xx responses)
- High latency (P95 >500ms)
- Service down (no metrics for 5 minutes)
- High memory usage (>85% heap)

### Phase 6: Distributed Tracing (Optional)

Deploy OpenTelemetry Collector for:
- Request tracing across services
- Performance bottleneck identification
- Service dependency mapping

## Related Documentation

- [Observability Stack Overview](../OBSERVABILITY.md)
- [Phase 2: Helm Deployment Guide](./phase2-helm-deployment.md)
- [Observability CD Workflow](./cd-workflow.md)
- [Backend Helm Chart](../../helm/backend/README.md)

---

**Last Updated**: 2025-12-14
**Phase**: 3 - Backend Service Integration
**Status**: Complete

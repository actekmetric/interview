# Observability Strategy

## Overview

This document describes the observability features implemented in the Tekmetric Interview Backend Service, including metrics collection, logging, and distributed tracing capabilities.

**Observability Pillars:**
- **Metrics:** Application and infrastructure performance data
- **Logging:** Event-based application and system logs
- **Tracing:** Distributed request tracing across services

---

## Current Implementation

### 1. Spring Boot Actuator

**Status:** ✅ Fully Implemented

Spring Boot Actuator provides production-ready features for monitoring and managing the application.

**Endpoints Available:**
- `/actuator/health` - Overall application health
- `/actuator/health/liveness` - Kubernetes liveness probe
- `/actuator/health/readiness` - Kubernetes readiness probe
- `/actuator/info` - Application metadata
- `/actuator/metrics` - Available metrics list
- `/actuator/metrics/{metricName}` - Specific metric details
- `/actuator/prometheus` - Prometheus-formatted metrics

**Configuration:**
```properties
# Exposed endpoints
management.endpoints.web.exposure.include=health,info,metrics,prometheus

# Health probes
management.endpoint.health.probes.enabled=true
management.health.livenessState.enabled=true
management.health.readinessState.enabled=true

# Prometheus metrics
management.metrics.export.prometheus.enabled=true
```

**Health Checks:**
- Database connectivity (H2)
- Disk space availability
- Liveness state
- Readiness state

---

### 2. OpenTelemetry Java Agent

**Status:** ✅ Integrated (Ready for use)

OpenTelemetry (OTEL) Java agent is pre-installed in the Docker image for automatic instrumentation.

**Agent Details:**
- **Version:** 1.32.0
- **Download URL:** `https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.32.0/opentelemetry-javaagent.jar`
- **Installation:** Baked into Docker image at `/opt/opentelemetry/opentelemetry-javaagent.jar`

**Automatic Instrumentation For:**
- HTTP servers (Spring Boot)
- HTTP clients (RestTemplate, WebClient)
- JDBC database calls
- Logging frameworks
- JVM metrics

**Configuration (via Helm values):**
```yaml
observability:
  enabled: true
  otel:
    enabled: false  # Enable when OTEL collector is deployed
    endpoint: "http://otel-collector.observability.svc.cluster.local:4318"
    protocol: "http/protobuf"
```

**When Enabled, Environment Variables:**
```bash
JAVA_TOOL_OPTIONS="-javaagent:/opt/opentelemetry/opentelemetry-javaagent.jar"
OTEL_SERVICE_NAME="backend"
OTEL_RESOURCE_ATTRIBUTES="service.name=backend,service.namespace=backend-services,deployment.environment=dev"
OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4318"
OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf"
```

**To Enable:**
1. Deploy OpenTelemetry Collector to cluster
2. Set `observability.otel.enabled: true` in Helm values
3. Configure collector endpoint
4. Redeploy application

---

### 3. Prometheus Metrics

**Status:** ✅ Ready for collection (metrics exposed, scraper not deployed)

The application exposes Prometheus-compatible metrics at `/actuator/prometheus`.

**Helm Chart Configuration:**
```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

**These annotations tell Prometheus:**
- Scrape this pod for metrics
- Use port 8080
- Metrics are available at `/actuator/prometheus`

---

### 4. CloudWatch Logging

**Status:** ✅ Implemented at EKS level

EKS cluster audit logs and control plane logs are forwarded to CloudWatch.

**Enabled Log Types:**
- API server logs
- Audit logs
- Authenticator logs
- Controller manager logs
- Scheduler logs

**VPC Flow Logs:**
- Network traffic monitoring
- Security analysis
- Troubleshooting connectivity issues

**Accessing Logs:**
```bash
# View in CloudWatch
aws logs tail /aws/eks/tekmetric-dev/cluster --follow

# View pod logs directly
kubectl logs -f deployment/backend -n backend-services

# View logs for all pods in namespace
kubectl logs -f -l app=backend -n backend-services --all-containers=true
```

---

## Available Metrics

### JVM Metrics

**Memory:**
- `jvm.memory.used` - Current memory usage (heap/non-heap)
- `jvm.memory.max` - Maximum available memory
- `jvm.memory.committed` - Committed memory
- `jvm.buffer.memory.used` - Buffer pool usage
- `jvm.buffer.count` - Buffer pool count

**Garbage Collection:**
- `jvm.gc.pause` - GC pause duration
- `jvm.gc.memory.allocated` - Memory allocated between GCs
- `jvm.gc.memory.promoted` - Memory promoted to old generation

**Threads:**
- `jvm.threads.live` - Current thread count
- `jvm.threads.daemon` - Daemon thread count
- `jvm.threads.peak` - Peak thread count
- `jvm.threads.states` - Thread states distribution

**Classes:**
- `jvm.classes.loaded` - Currently loaded classes
- `jvm.classes.unloaded` - Total unloaded classes

---

### HTTP Server Metrics

**Requests:**
- `http.server.requests` - HTTP request count and duration
  - Tags: method, uri, status, outcome, exception
  - Statistics: count, sum, max
- Response times by endpoint
- Request rate by HTTP method
- Error rate by status code

**Example Queries:**
```promql
# Request rate
rate(http_server_requests_seconds_count[5m])

# Average response time
rate(http_server_requests_seconds_sum[5m]) / rate(http_server_requests_seconds_count[5m])

# Error rate (5xx responses)
sum(rate(http_server_requests_seconds_count{status=~"5.."}[5m])) / sum(rate(http_server_requests_seconds_count[5m]))

# 95th percentile latency
histogram_quantile(0.95, rate(http_server_requests_seconds_bucket[5m]))
```

---

### System Metrics

**Process:**
- `process.uptime` - Application uptime in seconds
- `process.cpu.usage` - Process CPU usage (0-1)
- `process.start.time` - Process start timestamp
- `process.files.open` - Currently open file descriptors
- `process.files.max` - Maximum file descriptors

**System:**
- `system.cpu.usage` - System CPU usage (0-1)
- `system.cpu.count` - Number of CPU cores
- `system.load.average.1m` - 1-minute load average

**Disk:**
- `disk.free` - Free disk space
- `disk.total` - Total disk space

---

### Example Metrics Output

```promql
# JVM Memory Usage
jvm_memory_used_bytes{area="heap",id="G1 Eden Space"} 25165824
jvm_memory_used_bytes{area="heap",id="G1 Old Gen"} 16777216
jvm_memory_max_bytes{area="heap"} 268435456

# HTTP Request Metrics
http_server_requests_seconds_count{exception="None",method="GET",outcome="SUCCESS",status="200",uri="/api/welcome"} 1523
http_server_requests_seconds_sum{exception="None",method="GET",outcome="SUCCESS",status="200",uri="/api/welcome"} 45.234

# Process Metrics
process_uptime_seconds 3600.123
process_cpu_usage 0.023
process_files_open_files 42

# GC Metrics
jvm_gc_pause_seconds_count{action="end of minor GC",cause="Allocation Failure"} 123
jvm_gc_pause_seconds_sum{action="end of minor GC",cause="Allocation Failure"} 1.234
```

---

## Monitoring Architecture (Would-be Complete Stack)

### Overview Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        EKS Cluster                           │
│                                                              │
│  ┌──────────────┐        ┌──────────────┐                  │
│  │   Backend    │───────▶│ OTEL         │                  │
│  │   Pods       │ traces │ Collector    │                  │
│  │              │        │              │                  │
│  │ :8080        │        └──────┬───────┘                  │
│  │ /actuator/   │               │                           │
│  │  prometheus  │               │ traces                    │
│  └──────┬───────┘               │                           │
│         │                       │                           │
│         │ scrape                ▼                           │
│         │              ┌──────────────┐                     │
│  ┌──────▼───────┐      │   Jaeger/    │                     │
│  │ Prometheus   │      │   Tempo      │                     │
│  │              │      └──────────────┘                     │
│  │ :9090        │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         │ query                                             │
│         │                                                    │
│  ┌──────▼───────┐                                           │
│  │  Grafana     │                                           │
│  │  :3000       │                                           │
│  └──────────────┘                                           │
│                                                              │
└─────────────────────────────────────────────────────────────┘
         │
         │ logs
         ▼
┌──────────────┐
│  CloudWatch  │
│  Logs        │
└──────────────┘
```

---

### Prometheus Deployment (Future)

**Recommended:** Use `kube-prometheus-stack` Helm chart

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --values prometheus-values.yaml
```

**What's Included:**
- Prometheus Operator
- Prometheus server
- Grafana
- Alertmanager
- Node exporter
- Kube-state-metrics
- Pre-configured dashboards

**ServiceMonitor for Backend:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-service
  namespace: backend-services
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
    scrapeTimeout: 10s
```

---

### Grafana Dashboards (Would-be)

**Backend Service Dashboard:**
- Request rate (requests/sec)
- Average response time
- Error rate (% of 5xx responses)
- 95th percentile latency
- Request count by endpoint
- JVM heap usage
- GC pause time
- Thread count
- CPU usage
- Active connections

**Example Panels:**

**1. Request Rate**
```promql
sum(rate(http_server_requests_seconds_count{namespace="backend-services"}[5m]))
```

**2. Error Rate**
```promql
sum(rate(http_server_requests_seconds_count{namespace="backend-services",status=~"5.."}[5m]))
/
sum(rate(http_server_requests_seconds_count{namespace="backend-services"}[5m])) * 100
```

**3. JVM Heap Usage**
```promql
jvm_memory_used_bytes{area="heap",namespace="backend-services"}
/
jvm_memory_max_bytes{area="heap",namespace="backend-services"} * 100
```

**4. P95 Latency**
```promql
histogram_quantile(0.95,
  sum(rate(http_server_requests_seconds_bucket{namespace="backend-services"}[5m])) by (le)
)
```

**EKS Cluster Dashboard:**
- Node CPU usage
- Node memory usage
- Pod count by namespace
- Container restarts
- Network traffic
- Persistent volume usage

---

### Alerting Rules (Would-be)

**Critical Alerts:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: backend-alerts
  namespace: backend-services
spec:
  groups:
  - name: backend
    interval: 30s
    rules:
    - alert: BackendServiceDown
      expr: up{job="backend-service"} == 0
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "Backend service is down"
        description: "Backend service in {{ $labels.namespace }} has been down for more than 1 minute."

    - alert: HighErrorRate
      expr: |
        sum(rate(http_server_requests_seconds_count{status=~"5..",namespace="backend-services"}[5m]))
        /
        sum(rate(http_server_requests_seconds_count{namespace="backend-services"}[5m])) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} (threshold: 5%)"

    - alert: HighMemoryUsage
      expr: |
        jvm_memory_used_bytes{area="heap",namespace="backend-services"}
        /
        jvm_memory_max_bytes{area="heap",namespace="backend-services"} > 0.90
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High JVM heap usage"
        description: "JVM heap usage is {{ $value | humanizePercentage }} (threshold: 90%)"

    - alert: HighResponseTime
      expr: |
        histogram_quantile(0.95,
          sum(rate(http_server_requests_seconds_bucket{namespace="backend-services"}[5m])) by (le)
        ) > 1.0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "High response time"
        description: "P95 latency is {{ $value }}s (threshold: 1s)"

    - alert: FrequentGC
      expr: rate(jvm_gc_pause_seconds_count{namespace="backend-services"}[1m]) > 10
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Frequent garbage collection"
        description: "GC is running {{ $value }} times per second (threshold: 10/sec)"
```

---

## Logging Strategy

### Application Logs

**Framework:** Spring Boot Logging (Logback)

**Log Levels:**
- ERROR: Critical errors requiring immediate attention
- WARN: Warning messages about potential issues
- INFO: Informational messages about application flow
- DEBUG: Detailed debugging information (dev only)
- TRACE: Very detailed tracing information (dev only)

**Log Format:**
```
%d{yyyy-MM-dd HH:mm:ss} [%thread] %-5level %logger{36} - %msg%n
```

**Example Logs:**
```
2025-01-13 10:30:45 [http-nio-8080-exec-1] INFO  c.i.resource.WelcomeResource - Processing request for /api/welcome
2025-01-13 10:30:45 [http-nio-8080-exec-1] DEBUG c.i.service.WelcomeService - Fetching welcome message
2025-01-13 10:30:45 [http-nio-8080-exec-1] INFO  c.i.resource.WelcomeResource - Request completed successfully in 15ms
```

**Accessing Logs:**
```bash
# Real-time logs
kubectl logs -f deployment/backend -n backend-services

# Last 100 lines
kubectl logs --tail=100 deployment/backend -n backend-services

# Logs from previous container (after restart)
kubectl logs --previous deployment/backend -n backend-services

# Logs from all pods
kubectl logs -l app=backend -n backend-services --all-containers=true

# Export logs to file
kubectl logs deployment/backend -n backend-services > backend.log
```

---

### Structured Logging (Future Enhancement)

**Recommended:** Use Logstash JSON encoder for structured logs

```xml
<!-- pom.xml -->
<dependency>
    <groupId>net.logstash.logback</groupId>
    <artifactId>logstash-logback-encoder</artifactId>
    <version>7.3</version>
</dependency>
```

**Benefits:**
- Machine-readable format
- Easy parsing and querying
- Better integration with log aggregation tools
- Contextual information (trace ID, user ID, etc.)

**Example Structured Log:**
```json
{
  "@timestamp": "2025-01-13T10:30:45.123Z",
  "level": "INFO",
  "logger": "com.interview.resource.WelcomeResource",
  "thread": "http-nio-8080-exec-1",
  "message": "Processing request",
  "trace_id": "abc123",
  "span_id": "def456",
  "method": "GET",
  "uri": "/api/welcome",
  "status": 200,
  "duration_ms": 15
}
```

---

### Log Aggregation (Future)

**Option 1: ELK Stack (Elasticsearch, Logstash, Kibana)**
- Centralized log storage
- Full-text search
- Advanced querying
- Visualization and dashboards

**Option 2: Loki (Grafana Loki)**
- Lightweight alternative to ELK
- Better integration with Grafana
- Lower resource requirements
- Label-based indexing

**Option 3: CloudWatch Logs Insights**
- Already collecting EKS logs
- AWS-native solution
- Query language for log analysis
- No additional infrastructure

**Example CloudWatch Insights Query:**
```
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
```

---

## Distributed Tracing

### OpenTelemetry Tracing

**Current Status:** Agent installed, waiting for collector

**What Tracing Provides:**
- End-to-end request visibility
- Performance bottleneck identification
- Service dependency mapping
- Error correlation across services

**Trace Components:**
- **Trace:** Complete journey of a request
- **Span:** Individual operation within a trace
- **Context:** Metadata about the trace (IDs, tags)

**Example Trace Flow:**
```
Trace ID: abc123xyz
├─ Span 1: HTTP GET /api/welcome (50ms)
   ├─ Span 2: Service.getWelcome (30ms)
   │  └─ Span 3: Database query (20ms)
   └─ Span 4: Response serialization (5ms)
```

---

### OpenTelemetry Collector Deployment (Future)

```yaml
# otel-collector-values.yaml
mode: deployment

image:
  repository: otel/opentelemetry-collector-k8s

config:
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
        grpc:
          endpoint: 0.0.0.0:4317

  processors:
    batch:
      timeout: 10s
      send_batch_size: 1024

    memory_limiter:
      limit_mib: 512
      spike_limit_mib: 128
      check_interval: 5s

  exporters:
    jaeger:
      endpoint: jaeger-collector:14250
      tls:
        insecure: true

    prometheus:
      endpoint: "0.0.0.0:8889"

    logging:
      loglevel: debug

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [jaeger, logging]

      metrics:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [prometheus, logging]
```

**Deploy:**
```bash
helm install otel-collector open-telemetry/opentelemetry-collector \
  --namespace observability \
  --values otel-collector-values.yaml
```

---

### Jaeger Deployment (Future)

```bash
# Install Jaeger operator
kubectl create namespace observability
kubectl create -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.51.0/jaeger-operator.yaml -n observability

# Deploy Jaeger instance
kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:1.51
    options:
      log-level: info
  storage:
    type: memory
  ingress:
    enabled: true
  ui:
    options:
      dependencies:
        menuEnabled: true
EOF
```

**Access Jaeger UI:**
```bash
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Open: http://localhost:16686
```

---

## Implementation Roadmap

### Phase 1: Current State ✅
- [x] Spring Boot Actuator enabled
- [x] Health probes configured
- [x] Prometheus metrics exposed
- [x] OpenTelemetry agent integrated
- [x] CloudWatch logging enabled
- [x] Helm chart annotations for Prometheus

### Phase 2: Metrics Collection (1-2 days)
- [ ] Deploy kube-prometheus-stack
- [ ] Configure ServiceMonitor for backend
- [ ] Verify metrics scraping
- [ ] Create basic Grafana dashboard
- [ ] Set up basic alerts

### Phase 3: Tracing (2-3 days)
- [ ] Deploy OpenTelemetry Collector
- [ ] Deploy Jaeger/Tempo
- [ ] Enable OTEL in backend Helm values
- [ ] Verify traces are collected
- [ ] Create service dependency map

### Phase 4: Advanced Observability (1 week)
- [ ] Deploy log aggregation (Loki/ELK)
- [ ] Implement structured logging
- [ ] Create comprehensive dashboards
- [ ] Set up alerting to Slack/PagerDuty
- [ ] Add SLO/SLI monitoring
- [ ] Implement request sampling for high-traffic scenarios

---

## Best Practices

### 1. Metrics
- Use consistent naming conventions (Prometheus style)
- Add relevant tags/labels (environment, version, instance)
- Monitor RED metrics: Rate, Errors, Duration
- Set up SLIs (Service Level Indicators)
- Avoid high-cardinality labels

### 2. Logging
- Use appropriate log levels
- Include context (trace ID, user ID, request ID)
- Avoid logging sensitive data (passwords, tokens)
- Use structured logging for machine parsing
- Implement log sampling for high-volume scenarios

### 3. Tracing
- Enable for user-facing requests
- Sample traces in production (e.g., 1%)
- Include relevant span attributes
- Propagate context across services
- Monitor trace sampling rate

### 4. Alerting
- Alert on symptoms, not causes
- Make alerts actionable
- Include runbook links
- Set appropriate thresholds
- Avoid alert fatigue

---

## Troubleshooting

### Metrics Not Appearing in Prometheus

**Symptoms:** Prometheus not scraping backend metrics

**Solutions:**
1. Verify pod annotations are correct
2. Check ServiceMonitor selector matches service labels
3. Verify Prometheus has network access to pods
4. Check Prometheus targets page: `http://prometheus:9090/targets`
5. Verify metrics endpoint is accessible: `curl http://<pod-ip>:8080/actuator/prometheus`

### Traces Not Appearing in Jaeger

**Symptoms:** No traces visible in Jaeger UI

**Solutions:**
1. Verify OTEL collector is running: `kubectl get pods -n observability`
2. Check OTEL collector logs: `kubectl logs -n observability deployment/otel-collector`
3. Verify backend OTEL configuration is enabled in Helm values
4. Check backend logs for OTEL initialization
5. Verify network connectivity: Backend → OTEL Collector → Jaeger

### High Memory Usage

**Symptoms:** Pod OOMKilled, high heap usage

**Solutions:**
1. Check JVM heap settings in Helm values
2. Review GC logs: Look for frequent full GCs
3. Analyze heap dump: `kubectl exec -it <pod> -- jmap -dump:format=b,file=/tmp/heap.bin 1`
4. Increase memory limits if needed
5. Optimize application code

---

## Cost Considerations

**CloudWatch Logs:**
- $0.50 per GB ingested
- $0.03 per GB stored per month
- Use log retention policies to control costs

**Prometheus (Self-hosted):**
- No per-metric costs
- Infrastructure costs only (storage, compute)
- Typically cheaper than managed solutions for moderate scale

**Managed Prometheus/Grafana (AWS AMP/AMG):**
- AWS Managed Prometheus: $0.30 per million samples ingested
- AWS Managed Grafana: $9/user/month
- Consider for production at scale

**Storage:**
- Metrics: ~1-2 GB per service per month
- Logs: Variable, depends on verbosity
- Traces: ~100-500 MB per service per month (with sampling)

---

## References

- [Spring Boot Actuator Documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [AWS Observability Best Practices](https://aws-observability.github.io/observability-best-practices/)

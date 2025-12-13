# Backend Service API Documentation

## Overview

This document describes all available REST API endpoints for the Tekmetric Interview Backend Service.

**Base URL:**
- Local development: `http://localhost:8080`
- Kubernetes (port-forward): `http://localhost:8080`
- Kubernetes (ingress): `http://backend-dev.tekmetric.local`
- EKS (LoadBalancer): `http://<load-balancer-dns>:8080`

**Technology Stack:**
- Spring Boot 3.4.5 (upgraded to resolve security issues)
- Java 17 (upgraded to resolve security issues)
- H2 In-Memory Database
- Spring Boot Actuator for observability

---

## Application Endpoints

### GET /api/welcome

Returns a welcome message.

**Request:**
```bash
curl -X GET http://localhost:8080/api/welcome
```

**Response:**
```
HTTP/1.1 200 OK
Content-Type: text/plain

Welcome to the interview project!
```

**Status Codes:**
- `200 OK` - Success

---

## Spring Boot Actuator Endpoints

Spring Boot Actuator provides production-ready features for monitoring and managing the application.

### GET /actuator

Lists all available actuator endpoints.

**Request:**
```bash
curl http://localhost:8080/actuator
```

**Response:**
```json
{
  "_links": {
    "self": {
      "href": "http://localhost:8080/actuator"
    },
    "health": {
      "href": "http://localhost:8080/actuator/health"
    },
    "health-path": {
      "href": "http://localhost:8080/actuator/health/{*path}"
    },
    "info": {
      "href": "http://localhost:8080/actuator/info"
    },
    "metrics": {
      "href": "http://localhost:8080/actuator/metrics"
    }
  }
}
```

---

### GET /actuator/health

Returns the overall health status of the application.

**Request:**
```bash
curl http://localhost:8080/actuator/health
```

**Response:**
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "H2",
        "validationQuery": "isValid()"
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 250790436864,
        "free": 150000000000,
        "threshold": 10485760,
        "exists": true
      }
    },
    "livenessState": {
      "status": "UP"
    },
    "ping": {
      "status": "UP"
    },
    "readinessState": {
      "status": "UP"
    }
  }
}
```

**Status Codes:**
- `200 OK` - Application is healthy
- `503 Service Unavailable` - Application is unhealthy

**Used By:** General health monitoring

---

### GET /actuator/health/liveness

Kubernetes liveness probe endpoint. Indicates if the application is running.

**Request:**
```bash
curl http://localhost:8080/actuator/health/liveness
```

**Response:**
```json
{
  "status": "UP"
}
```

**Status Codes:**
- `200 OK` - Application is alive
- `503 Service Unavailable` - Application should be restarted

**Used By:** Kubernetes liveness probe (configured in Helm chart)

---

### GET /actuator/health/readiness

Kubernetes readiness probe endpoint. Indicates if the application is ready to receive traffic.

**Request:**
```bash
curl http://localhost:8080/actuator/health/readiness
```

**Response:**
```json
{
  "status": "UP"
}
```

**Status Codes:**
- `200 OK` - Application is ready to receive traffic
- `503 Service Unavailable` - Application is not ready (warming up, dependencies unavailable, etc.)

**Used By:**
- Kubernetes readiness probe (configured in Helm chart)
- Kubernetes startup probe (configured in Helm chart)

---

### GET /actuator/info

Returns application information and metadata.

**Request:**
```bash
curl http://localhost:8080/actuator/info
```

**Response:**
```json
{
  "app": {
    "name": "interview",
    "version": "1.0-SNAPSHOT"
  }
}
```

**Status Codes:**
- `200 OK` - Success

---

### GET /actuator/metrics

Lists all available metrics.

**Request:**
```bash
curl http://localhost:8080/actuator/metrics
```

**Response:**
```json
{
  "names": [
    "jvm.memory.used",
    "jvm.memory.max",
    "jvm.gc.pause",
    "jvm.threads.live",
    "process.uptime",
    "process.cpu.usage",
    "http.server.requests",
    "system.cpu.usage",
    "system.load.average.1m"
  ]
}
```

**Status Codes:**
- `200 OK` - Success

---

### GET /actuator/metrics/{metricName}

Returns detailed information about a specific metric.

**Request:**
```bash
# JVM Memory Usage
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# HTTP Request Metrics
curl http://localhost:8080/actuator/metrics/http.server.requests

# CPU Usage
curl http://localhost:8080/actuator/metrics/process.cpu.usage
```

**Response Example (JVM Memory):**
```json
{
  "name": "jvm.memory.used",
  "description": "The amount of used memory",
  "baseUnit": "bytes",
  "measurements": [
    {
      "statistic": "VALUE",
      "value": 125829120
    }
  ],
  "availableTags": [
    {
      "tag": "area",
      "values": ["heap", "nonheap"]
    },
    {
      "tag": "id",
      "values": ["G1 Eden Space", "G1 Old Gen", "G1 Survivor Space"]
    }
  ]
}
```

**Common Metrics:**
- `jvm.memory.used` - JVM memory usage
- `jvm.memory.max` - Maximum JVM memory
- `jvm.gc.pause` - Garbage collection pause times
- `jvm.threads.live` - Current thread count
- `http.server.requests` - HTTP request metrics (count, duration, status codes)
- `process.uptime` - Application uptime
- `process.cpu.usage` - Process CPU usage
- `system.cpu.usage` - System CPU usage
- `system.load.average.1m` - System load average

---

### GET /actuator/prometheus

Prometheus-formatted metrics endpoint for scraping.

**Request:**
```bash
curl http://localhost:8080/actuator/prometheus
```

**Response (excerpt):**
```
# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{area="heap",id="G1 Eden Space",} 2.5165824E7
jvm_memory_used_bytes{area="heap",id="G1 Old Gen",} 1.6777216E7
jvm_memory_used_bytes{area="heap",id="G1 Survivor Space",} 0.0

# HELP jvm_memory_max_bytes The maximum amount of memory in bytes
# TYPE jvm_memory_max_bytes gauge
jvm_memory_max_bytes{area="heap",id="G1 Eden Space",} -1.0
jvm_memory_max_bytes{area="heap",id="G1 Old Gen",} 2.68435456E8

# HELP process_uptime_seconds The uptime of the Java virtual machine
# TYPE process_uptime_seconds gauge
process_uptime_seconds 45.123

# HELP http_server_requests_seconds
# TYPE http_server_requests_seconds summary
http_server_requests_seconds_count{exception="None",method="GET",outcome="SUCCESS",status="200",uri="/api/welcome",} 5.0
http_server_requests_seconds_sum{exception="None",method="GET",outcome="SUCCESS",status="200",uri="/api/welcome",} 0.123456

# HELP process_cpu_usage The "recent cpu usage" for the Java Virtual Machine process
# TYPE process_cpu_usage gauge
process_cpu_usage 0.023
```

**Key Metric Categories:**
- **JVM Metrics:** Memory, GC, threads, class loading
- **HTTP Metrics:** Request count, duration, status codes by endpoint
- **System Metrics:** CPU usage, load average
- **Process Metrics:** Uptime, file descriptors

**Used By:**
- Prometheus server for metrics collection
- Grafana dashboards for visualization
- Alerting rules

**Configuration:**
The Helm chart includes Prometheus scraping annotations:
```yaml
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "8080"
  prometheus.io/path: "/actuator/prometheus"
```

---

## Development/Debug Endpoints

### H2 Console

H2 provides a web-based console for database inspection.

**URL:** `http://localhost:8080/h2-console`

**Connection Details:**
- **JDBC URL:** `jdbc:h2:mem:testdb`
- **Username:** `sa`
- **Password:** `password`

**Note:** Only enabled in development/local environments. Disabled in production.

---

## Testing the API

### Using curl

```bash
# Test basic API endpoint
curl http://localhost:8080/api/welcome

# Test health endpoint
curl http://localhost:8080/actuator/health

# Test liveness probe
curl http://localhost:8080/actuator/health/liveness

# Test readiness probe
curl http://localhost:8080/actuator/health/readiness

# List all metrics
curl http://localhost:8080/actuator/metrics

# Get specific metric
curl http://localhost:8080/actuator/metrics/jvm.memory.used

# Get Prometheus metrics
curl http://localhost:8080/actuator/prometheus

# Pretty print JSON responses
curl http://localhost:8080/actuator/health | jq '.'
```

### Port Forwarding in Kubernetes

If ingress is not available, use kubectl port-forward:

```bash
# Find the pod name
kubectl get pods -n backend-services

# Port forward to the backend service
kubectl port-forward -n backend-services svc/backend 8080:8080

# In another terminal, test the endpoints
curl http://localhost:8080/actuator/health
```

### Load Testing

Simple load test using Apache Bench (if available):

```bash
# 100 requests, 10 concurrent
ab -n 100 -c 10 http://localhost:8080/api/welcome

# With keep-alive
ab -n 1000 -c 50 -k http://localhost:8080/api/welcome
```

---

## Observability Integration

### OpenTelemetry

The application includes OpenTelemetry Java agent for distributed tracing:

- **Agent Version:** 1.32.0
- **Instrumentation:** Automatic for Spring Boot, HTTP clients, JDBC
- **Configuration:** Via environment variables in Helm chart
- **Endpoint:** Configurable via `OTEL_EXPORTER_OTLP_ENDPOINT`

When OpenTelemetry collector is deployed, traces will be automatically exported.

### CloudWatch Logs

Application logs are captured by Kubernetes and forwarded to CloudWatch:

```bash
# View logs in Kubernetes
kubectl logs -f deployment/backend -n backend-services

# View logs in AWS CloudWatch
aws logs tail /aws/eks/tekmetric-dev/application --follow
```

### Prometheus Metrics Collection

The application exposes Prometheus-compatible metrics at `/actuator/prometheus`. When Prometheus is deployed to the cluster, it will automatically scrape metrics based on the pod annotations.

Example ServiceMonitor (for Prometheus Operator):
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: backend-service
  namespace: backend-services
spec:
  selector:
    matchLabels:
      app: backend
  endpoints:
  - port: http
    path: /actuator/prometheus
    interval: 30s
```

---

## Security Considerations

### Actuator Security

In production environments, actuator endpoints should be:

1. **Protected by authentication** - Use Spring Security
2. **Exposed on management port** - Separate from application port
3. **Restricted by network** - Only accessible from monitoring systems
4. **Limited exposure** - Only expose necessary endpoints

Current configuration (dev):
- All actuator endpoints are publicly accessible
- Suitable for development/demo only
- Production should implement proper security

### Recommended Production Configuration

```properties
# Use separate management port
management.server.port=8081

# Expose only required endpoints
management.endpoints.web.exposure.include=health,prometheus

# Don't show detailed health information publicly
management.endpoint.health.show-details=when-authorized

# Require authentication for sensitive endpoints
management.endpoints.web.base-path=/actuator
```

---

## Troubleshooting

### Endpoint Returns 404

**Problem:** Actuator endpoint returns 404

**Solutions:**
1. Verify actuator is included in dependencies (check `pom.xml`)
2. Check `application.properties` has correct exposure configuration
3. Verify Spring Boot version supports the endpoint
4. Check application logs for startup errors

### Health Check Returns DOWN

**Problem:** `/actuator/health` returns `503 Service Unavailable`

**Solutions:**
1. Check H2 database connectivity
2. Verify disk space availability
3. Check application logs for errors: `kubectl logs <pod-name>`
4. Inspect individual health indicators: `curl http://localhost:8080/actuator/health | jq '.components'`

### Metrics Not Available

**Problem:** Prometheus metrics endpoint not found

**Solutions:**
1. Verify micrometer-registry-prometheus dependency is included
2. Check that `prometheus` is in `management.endpoints.web.exposure.include`
3. Restart application after configuration changes

### Connection Refused

**Problem:** Cannot connect to API

**Solutions:**
1. Verify pod is running: `kubectl get pods -n backend-services`
2. Check pod logs: `kubectl logs <pod-name> -n backend-services`
3. Verify service exists: `kubectl get svc -n backend-services`
4. Test from within cluster: `kubectl run curl --image=curlimages/curl -i --rm --restart=Never -- curl http://backend.backend-services:8080/actuator/health`

---

## API Evolution

This is a minimal API for interview/demonstration purposes. In a production environment, consider:

1. **Versioning:** Use `/api/v1/` prefix for versioned APIs
2. **Documentation:** Integrate Swagger/OpenAPI for interactive API docs
3. **Security:** Implement authentication (OAuth2, JWT) and authorization
4. **Rate Limiting:** Protect against abuse
5. **CORS:** Configure appropriate CORS policies
6. **Error Handling:** Standardized error response format
7. **Pagination:** For list endpoints
8. **Filtering/Sorting:** Query parameters for data endpoints
9. **Caching:** HTTP caching headers and ETag support
10. **Compression:** Enable gzip compression for responses

---

## References

- [Spring Boot Actuator Documentation](https://docs.spring.io/spring-boot/docs/2.3.x/reference/html/production-ready-features.html)
- [Micrometer Documentation](https://micrometer.io/docs)
- [Prometheus Exposition Formats](https://prometheus.io/docs/instrumenting/exposition_formats/)
- [Kubernetes Health Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [OpenTelemetry Java](https://opentelemetry.io/docs/instrumentation/java/)

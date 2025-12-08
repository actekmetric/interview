# Tekmetric Common Helm Chart

A comprehensive, production-ready Helm chart for deploying microservices on Kubernetes with built-in observability, autoscaling, and high availability features.

## Features

- **Modern Kubernetes Patterns**: Uses current best practices for deployments, services, and configurations
- **High Availability**: Built-in pod disruption budgets and affinity rules
- **Autoscaling**: Horizontal Pod Autoscaler with CPU and memory targets
- **Observability**: Native OpenTelemetry integration for metrics, traces, and logs
- **Health Checks**: Configurable startup, liveness, and readiness probes
- **Security**: Support for pod security contexts, network policies, and secrets
- **Flexible Configuration**: Comprehensive values structure for customization

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+

## Installation

### Add the Repository

```bash
helm repo add tekmetric https://charts.tekmetric.com
helm repo update
```

### Install the Chart

```bash
helm install my-service tekmetric/tekmetric-common-chart \
  --set image.repository=docker.io \
  --set image.name=myapp \
  --set image.tag=1.0.0
```

### Install with Custom Values

```bash
helm install my-service tekmetric/tekmetric-common-chart -f values.yaml
```

## Configuration

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full resource names | `""` |
| `replicaCount` | Number of replicas | `1` |

### Image Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Image registry URL | `""` |
| `image.name` | Image name | `""` |
| `image.tag` | Image tag | Chart appVersion |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `imagePullSecrets` | Image pull secrets | `[]` |

### Service Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Kubernetes service type | `ClusterIP` |
| `service.port` | Service port | `8080` |
| `service.managementPort` | Management/metrics port | `null` |
| `service.additionalPorts` | Additional ports to expose | `[]` |
| `service.annotations` | Service annotations | `{}` |

### Ingress Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `nginx` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | `[]` |
| `ingress.tls` | TLS configuration | `[]` |

### Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPU` | Target CPU utilization | `80` |
| `autoscaling.targetMemory` | Target memory utilization | `80` |

### Health Probes

| Parameter | Description | Default |
|-----------|-------------|---------|
| `probes.enabled` | Enable health probes | `true` |
| `probes.liveness.path` | Liveness probe path | `/health/live` |
| `probes.readiness.path` | Readiness probe path | `/health/ready` |
| `probes.startup.path` | Startup probe path | `/health/ready` |

### Observability

| Parameter | Description | Default |
|-----------|-------------|---------|
| `observability.enabled` | Enable observability | `true` |
| `observability.otel.enabled` | Enable OpenTelemetry | `true` |
| `observability.otel.endpoint` | OTLP collector endpoint | `http://otel-collector:4318` |
| `observability.otel.protocol` | OTLP protocol | `http/protobuf` |

### Resources

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources.limits.cpu` | CPU limit | `1000m` |
| `resources.limits.memory` | Memory limit | `1Gi` |
| `resources.requests.cpu` | CPU request | `250m` |
| `resources.requests.memory` | Memory request | `512Mi` |

## Examples

### Minimal Configuration

```yaml
image:
  repository: docker.io
  name: myapp
  tag: 1.0.0

service:
  port: 8080
```

### Production Configuration with Autoscaling

```yaml
image:
  repository: gcr.io/myproject
  name: myapp
  tag: 2.1.0
  pullPolicy: Always

replicaCount: 3

service:
  type: ClusterIP
  port: 8080
  managementPort: 9090

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: app.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: app-tls
      hosts:
        - app.example.com

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPU: 70
  targetMemory: 75

podDisruptionBudget:
  enabled: true
  minAvailable: 2

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi

probes:
  enabled: true
  liveness:
    path: /actuator/health/liveness
    port: management
  readiness:
    path: /actuator/health/readiness
    port: management

observability:
  enabled: true
  otel:
    enabled: true
    endpoint: "http://otel-collector.monitoring:4318"
```

### With JVM Configuration

```yaml
image:
  repository: docker.io
  name: java-app
  tag: 1.0.0

jvm:
  enabled: true
  options: "-Xms1g -Xmx2g -XX:+UseG1GC"

env:
  - name: SPRING_PROFILES_ACTIVE
    value: production
  - name: JAVA_TOOL_OPTIONS
    value: "-javaagent:/opt/dd-java-agent.jar"

observability:
  enabled: true
  otel:
    enabled: true
    javaOptions: "-Dotel.instrumentation.micrometer.enabled=true"
```

## Architecture

### Template Structure

```
templates/
├── deployment.yaml       # Main deployment resource
├── service.yaml         # Kubernetes service
├── ingress.yaml         # Ingress resource
├── hpa.yaml            # Horizontal Pod Autoscaler
├── pdb.yaml            # Pod Disruption Budget
├── _names.tpl          # Naming helpers
├── _labels.tpl         # Label helpers
├── _environment.tpl    # Environment variable helpers
└── _observability.tpl  # Observability configuration
```

### Design Principles

1. **Separation of Concerns**: Each template handles a specific Kubernetes resource
2. **Reusable Helpers**: Common functions extracted into helper templates
3. **Modern Patterns**: Uses current Kubernetes and Helm best practices
4. **Flexibility**: Comprehensive configuration options with sensible defaults
5. **Production Ready**: Built-in high availability and observability features

## Upgrading

### From Previous Versions

This chart has been completely redesigned. Please review the new values structure and migrate your configurations accordingly.

## Contributing

Contributions are welcome! Please read the contributing guidelines before submitting pull requests.

## License

Copyright © 2024 Tekmetric

## Support

For support, please contact: support@tekmetric.com

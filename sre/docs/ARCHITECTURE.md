# Infrastructure Architecture Documentation

## Related Documentation

This document provides complete technical architecture details. For related information:

- **Quick Overview:** [PRESENTATION.md](PRESENTATION.md) - 10-minute high-level presentation
- **Setup Instructions:** [SETUP-GUIDE.md](SETUP-GUIDE.md) - Step-by-step deployment guide
- **Git Workflow:** [GIT-WORKFLOW.md](GIT-WORKFLOW.md) - Branch strategy and deployment process
- **Staged Deployment:** [STAGED-DEPLOYMENT.md](STAGED-DEPLOYMENT.md) - Terraform deployment strategy details
- **CI/CD Workflows:** [github/workflows.md](github/workflows.md) - GitHub Actions implementation
- **Observability:** [OBSERVABILITY.md](OBSERVABILITY.md) - Metrics, logging, and tracing

---

## Overview

This document provides detailed architecture diagrams and explanations for the Tekmetric Interview SRE infrastructure.

**Key Features:**
- Multi-account AWS setup (dev, qa, prod isolation)
- Branch-based deployment strategy (develop → dev, release → qa, master → prod)
- Terraform staged deployment (4 stages to eliminate circular dependencies)
- GitHub Actions CI/CD with OIDC authentication
- Amazon EKS with production-ready Helm charts
- Comprehensive security (IRSA, VPC endpoints, encryption)

---

## 1. High-Level System Architecture

### AWS Multi-Account Setup

```mermaid
graph TB
    subgraph "AWS Organization"
        MGMT[Management Account<br/>Root + IAM admin]

        subgraph "Dev Account<br/>596308305263"
            DEV_VPC[VPC 10.0.0.0/16]
            DEV_EKS[EKS Cluster<br/>tekmetric-dev]
            DEV_ECR[ECR Repositories]
            DEV_S3[S3 Buckets<br/>State + Helm]
        end

        subgraph "QA Account<br/>234567890123"
            QA_VPC[VPC 10.1.0.0/16]
            QA_EKS[EKS Cluster<br/>tekmetric-qa]
            QA_ECR[ECR Repositories]
            QA_S3[S3 Buckets<br/>State + Helm]
        end

        subgraph "Prod Account<br/>345678901234"
            PROD_VPC[VPC 10.2.0.0/16]
            PROD_EKS[EKS Cluster<br/>tekmetric-prod]
            PROD_ECR[ECR Repositories]
            PROD_S3[S3 Buckets<br/>State + Helm]
        end
    end

    subgraph "GitHub"
        REPO[Source Repository]
        ACTIONS[GitHub Actions]
    end

    MGMT -.member.-> DEV_VPC
    MGMT -.member.-> QA_VPC
    MGMT -.member.-> PROD_VPC

    ACTIONS -->|OIDC Auth| DEV_ECR
    ACTIONS -->|OIDC Auth| QA_ECR
    ACTIONS -->|OIDC Auth| PROD_ECR

    ACTIONS -->|Deploy| DEV_EKS
    ACTIONS -->|Deploy| QA_EKS
    ACTIONS -->|Deploy| PROD_EKS
```

**Key Benefits:**
- **Isolation:** Blast radius limited to single account
- **Cost Tracking:** Separate billing per environment
- **Security:** Independent IAM policies and permissions
- **Compliance:** Easier audit trails and separation of duties

---

## 2. Detailed AWS Infrastructure (Single Environment)

### Network Architecture

```mermaid
graph TB
    INTERNET[Internet]

    subgraph "VPC 10.0.0.0/16"
        IGW[Internet Gateway]

        subgraph "us-east-1a"
            PUB1[Public Subnet<br/>10.0.0.0/24<br/>Routes to IGW]
            NAT1[NAT Gateway<br/>with Elastic IP]
            PRIV1[Private Subnet<br/>10.0.10.0/24<br/>Routes to NAT]
            EKS1[EKS Worker Nodes]
        end

        subgraph "us-east-1b"
            PUB2[Public Subnet<br/>10.0.1.0/24<br/>Routes to IGW]
            PRIV2[Private Subnet<br/>10.0.11.0/24<br/>Routes to NAT]
            EKS2[EKS Worker Nodes]
        end

        subgraph "us-east-1c"
            PUB3[Public Subnet<br/>10.0.2.0/24<br/>Routes to IGW]
            PRIV3[Private Subnet<br/>10.0.12.0/24<br/>Routes to NAT]
            EKS3[EKS Worker Nodes]
        end
    end

    %% Inbound traffic flow (from internet)
    INTERNET -->|Inbound| IGW
    IGW --> PUB1
    IGW --> PUB2
    IGW --> PUB3

    %% NAT Gateway placement
    PUB1 -.->|NAT resides in<br/>public subnet| NAT1

    %% Outbound traffic flow (from private to internet)
    PRIV1 -->|Outbound traffic| NAT1
    PRIV2 -->|Outbound traffic| NAT1
    PRIV3 -->|Outbound traffic| NAT1
    NAT1 -->|via IGW| INTERNET

    %% EKS nodes in private subnets
    PRIV1 -.- EKS1
    PRIV2 -.- EKS2
    PRIV3 -.- EKS3
```

**Network Flow Explained:**

**Inbound (Internet → EKS):**
```
Internet → Internet Gateway → Load Balancer (Public Subnet) → EKS Nodes (Private Subnet)
```

**Outbound (EKS → Internet):**
```
EKS Nodes (Private Subnet) → NAT Gateway (in Public Subnet) → Internet Gateway → Internet
```

**Key Components:**
- **3 Availability Zones:** High availability across multiple data centers
- **Public Subnets:**
  - Route table: `0.0.0.0/0 → Internet Gateway`
  - Contains: NAT Gateway, Load Balancers
  - Can receive inbound internet traffic
- **Private Subnets:**
  - Route table: `0.0.0.0/0 → NAT Gateway`
  - Contains: EKS worker nodes and pods
  - No direct internet access (inbound blocked)
  - Can make outbound requests via NAT Gateway
- **NAT Gateway:**
  - Deployed in public subnet (us-east-1a)
  - Has Elastic IP for outbound traffic
  - Allows private subnet resources to download packages, pull images, etc.
  - Blocks all inbound connections from internet
  - Single NAT in dev (cost optimization), per-AZ in prod (HA)
- **Security Groups:** Least privilege access between components

---

### EKS Cluster Architecture

```mermaid
graph TB
    subgraph "EKS Control Plane<br/>(AWS Managed)"
        API[API Server]
        SCHED[Scheduler]
        CTRL[Controller Manager]
        ETCD[etcd]
    end

    subgraph "Node Group<br/>(Private Subnets)"
        NODE1[Worker Node 1<br/>t3.medium]
        NODE2[Worker Node 2<br/>t3.medium]
        NODE3[Worker Node 3<br/>t3.medium]

        subgraph "Node 1 Pods"
            POD1A[Backend Pod]
            POD1B[CoreDNS]
        end

        subgraph "Node 2 Pods"
            POD2A[Backend Pod]
            POD2B[kube-proxy]
        end

        subgraph "Node 3 Pods"
            POD3A[System Pod]
            POD3B[VPC CNI]
        end
    end

    subgraph "EKS Addons"
        CNI[VPC CNI<br/>v1.18.1]
        COREDNS[CoreDNS<br/>v1.11.1]
        PROXY[kube-proxy<br/>v1.29.3]
        CSI[EBS CSI Driver<br/>v1.31.0]
    end

    API <-.kubectl.-> NODE1
    API <-.kubectl.-> NODE2
    API <-.kubectl.-> NODE3

    NODE1 --> POD1A
    NODE1 --> POD1B
    NODE2 --> POD2A
    NODE2 --> POD2B
    NODE3 --> POD3A
    NODE3 --> POD3B

    CNI -.network.-> POD1A
    CNI -.network.-> POD2A
    COREDNS -.dns.-> POD1A
    COREDNS -.dns.-> POD2A
```

**Key Features:**
- **Managed Control Plane:** AWS handles API server, etcd, etc.
- **Kubernetes 1.34:** Latest stable version (configurable per environment)
- **Managed Node Groups:** Auto-scaling, auto-healing
- **EKS Addons:** VPC CNI for networking, CoreDNS for DNS, EBS CSI for storage, CloudWatch Observability for logging
- **IRSA Enabled:** IAM Roles for Service Accounts for pod-level permissions

---

## 3. CI/CD Pipeline Architecture

### Branch-Based Deployment Strategy

The CI/CD pipeline uses **branch-based deployments** where branch names automatically determine target environments:

- **develop** → auto-deploy to **dev**
- **release/*** → auto-deploy to **qa**
- **master/main** → manual deploy to **prod**
- **feature/*** → build/test only (no deploy)
- **hotfix/*** → auto-deploy to **dev**

📖 **For complete Git workflow details**, see [Git Workflow Documentation](GIT-WORKFLOW.md)

### Complete CI/CD Flow

```mermaid
graph LR
    subgraph "Developer"
        CODE[Write Code]
        COMMIT[Git Commit]
        PUSH[Git Push]
    end

    subgraph "GitHub"
        REPO[Repository]
        PR[Pull Request]
        BRANCHES[Branches<br/>develop/release/master]
    end

    subgraph "GitHub Actions<br/>Backend CI"
        CHECKOUT[Checkout Code]
        BUILD[Maven Build]
        TEST[Unit Tests]
        BRANCH_DETECT[Detect Branch<br/>Determine Environment]
        VERSION[Generate Version<br/>Based on Branch]
        DOCKER[Docker Build<br/>Multi-platform]
        SCAN[Trivy Scan]
        PUSH_ECR[Push to ECR]
        HELM[Package Helm Chart]
        PUSH_S3[Push to S3]
    end

    subgraph "GitHub Actions<br/>Backend CD"
        TRIGGER[Trigger on CI Success]
        ENV_DETECT[Read Branch Metadata<br/>Select Environment]
        AUTH[AWS OIDC Auth]
        KUBE[Get EKS Credentials]
        DEPLOY[Helm Deploy]
        HEALTH[Health Check]
    end

    subgraph "AWS"
        ECR[ECR Registry<br/>Docker Images]
        S3[S3 Bucket<br/>Helm Charts]
        EKS[EKS Cluster]
    end

    CODE --> COMMIT
    COMMIT --> PUSH
    PUSH --> REPO
    REPO --> PR
    PR --> BRANCHES
    BRANCHES --> CHECKOUT

    CHECKOUT --> BUILD
    BUILD --> TEST
    TEST --> BRANCH_DETECT
    BRANCH_DETECT --> VERSION
    VERSION --> DOCKER
    DOCKER --> SCAN
    SCAN --> PUSH_ECR
    PUSH_ECR --> HELM
    HELM --> PUSH_S3

    PUSH_S3 --> TRIGGER
    TRIGGER --> ENV_DETECT
    ENV_DETECT --> AUTH
    AUTH --> KUBE
    KUBE --> DEPLOY
    DEPLOY --> HEALTH

    PUSH_ECR --> ECR
    PUSH_S3 --> S3
    DEPLOY --> EKS

    ECR -.pull.-> EKS
    S3 -.pull.-> DEPLOY
```

**Pipeline Stages:**

**Stage 1: CI (Continuous Integration)**
1. **Build:** Maven compiles Java code
2. **Test:** Execute unit tests
3. **Branch Detection:** Identify branch and determine target environment
4. **Version:** Generate semantic version with branch suffix (e.g., `-dev`, `-rc`)
5. **Docker:** Build multi-platform image (amd64, arm64)
6. **Scan:** Trivy security vulnerability scan
7. **Publish:** Push image to ECR, chart to S3

**Stage 2: CD (Continuous Deployment)**
1. **Trigger:** Automatic after CI success (for deployable branches)
2. **Environment Selection:** Read branch metadata to determine target environment
3. **Auth:** GitHub OIDC to AWS
4. **Deploy:** Helm upgrade --install to target environment
5. **Verify:** Health check endpoints

---

### GitHub Actions Workflow Relationships

```mermaid
graph TB
    subgraph "Infrastructure Workflows"
        TF[Terraform GitOps<br/>Manual + PR comments]
        DESTROY[Environment Destroy<br/>Manual only]
        START[Environment Start<br/>Manual]
        STOP[Environment Stop<br/>Manual]
    end

    subgraph "Application Workflows"
        CI[Backend CI<br/>Push to develop/release/master]
        CD[Backend CD<br/>After CI + Branch-based]
        COMMON[Common Helm Chart<br/>Chart changes]
    end

    subgraph "Custom Actions"
        TF_SETUP[terraform-setup]
        AWS_AUTH[aws-assume-role]
        DOCKER_BUILD[docker-build]
        ECR_PUB[ecr-publish]
        TRIVY[trivy-scan]
        HELM_PUB[helm-publish]
        HELM_DEP[helm-deploy]
        SCALE[workload-scale]
    end

    TF --> TF_SETUP
    TF --> AWS_AUTH

    CI --> DOCKER_BUILD
    CI --> ECR_PUB
    CI --> TRIVY
    CI --> HELM_PUB

    CD --> AWS_AUTH
    CD --> HELM_DEP

    STOP --> AWS_AUTH
    STOP --> SCALE

    START --> AWS_AUTH
    START --> SCALE

    COMMON --> HELM_PUB
```

**Workflow Types:**
- **Manual Dispatch:** User triggers from Actions UI
- **Push Trigger:** Automatic on code push (branch-based)
- **PR Trigger:** Automatic on pull request
- **PR Comment:** `/terraform plan dev` commands
- **Workflow Completion:** CD triggers after CI (branch-based environment)

### Branch-to-Environment Deployment Flow

```mermaid
graph TB
    subgraph "Git Branches"
        FEATURE[feature/*<br/>Work in progress]
        DEVELOP[develop<br/>Main development]
        RELEASE[release/*<br/>Release candidates]
        MASTER[master/main<br/>Production ready]
        HOTFIX[hotfix/*<br/>Urgent fixes]
    end

    subgraph "CI Actions"
        BUILD[Build & Test]
        VERSION_DEV[Version: x.x.x-dev]
        VERSION_RC[Version: x.x.x-rc]
        VERSION_PROD[Version: x.x.x]
        VERSION_HOTFIX[Version: x.x.x-hotfix]
    end

    subgraph "CD Deployments"
        DEV[dev Environment<br/>Auto-deploy]
        QA[qa Environment<br/>Auto-deploy]
        PROD[prod Environment<br/>Manual approval]
    end

    FEATURE --> BUILD
    BUILD -.no deploy.-> FEATURE

    DEVELOP --> BUILD
    BUILD --> VERSION_DEV
    VERSION_DEV --> DEV

    RELEASE --> BUILD
    BUILD --> VERSION_RC
    VERSION_RC --> QA

    MASTER --> BUILD
    BUILD --> VERSION_PROD
    VERSION_PROD --> PROD

    HOTFIX --> BUILD
    BUILD --> VERSION_HOTFIX
    VERSION_HOTFIX --> DEV

    style DEV fill:#90EE90
    style QA fill:#FFD700
    style PROD fill:#FF6B6B
```

**Deployment Rules:**
- ✅ **feature/*** → Build/test only, no deployment
- ✅ **develop** → Auto-deploy to dev (~5 min)
- ✅ **release/*** → Auto-deploy to qa (~5 min)
- ⚠️  **master** → Manual approval required for prod
- ⚠️  **hotfix/*** → Auto-deploy to dev for testing

📖 **For workflow details and usage examples**, see [Git Workflow Documentation](GIT-WORKFLOW.md)

---

## 4. Terraform Staged Deployment

### Dependency Flow

```mermaid
graph TB
    START[Start Deployment]

    subgraph "Stage 1: Networking"
        VPC[Create VPC]
        SUBNETS[Create Subnets]
        NAT[Create NAT Gateway]
        IGW[Create Internet Gateway]
        RT[Create Route Tables]
        SG[Create Security Groups]
        FLOW[Enable VPC Flow Logs]
    end

    subgraph "Stage 2: EKS Cluster"
        CLUSTER[Create EKS Cluster]
        NODES[Create Node Group]
        OIDC[Create OIDC Provider]
        ROLE[Create Node IAM Role]
    end

    subgraph "Stage 3: IAM"
        GITHUB_OIDC[GitHub OIDC Provider]
        GITHUB_ROLE[GitHub Actions Role]
        IRSA_ROLES[IRSA Roles for Pods]
    end

    subgraph "Stage 4: EKS Addons"
        VPC_CNI[VPC CNI Addon]
        COREDNS[CoreDNS Addon]
        KUBE_PROXY[kube-proxy Addon]
        EBS_CSI[EBS CSI Driver]
    end

    START --> VPC
    VPC --> SUBNETS
    SUBNETS --> NAT
    SUBNETS --> IGW
    NAT --> RT
    IGW --> RT
    RT --> SG
    SG --> FLOW

    FLOW --> CLUSTER
    CLUSTER --> OIDC
    CLUSTER --> NODES
    NODES --> ROLE

    OIDC --> GITHUB_OIDC
    OIDC --> IRSA_ROLES
    GITHUB_OIDC --> GITHUB_ROLE

    IRSA_ROLES --> VPC_CNI
    IRSA_ROLES --> EBS_CSI
    IRSA_ROLES --> COREDNS
    IRSA_ROLES --> KUBE_PROXY
```

**Why Staged Deployment?**

**The Problem:**
- EKS cluster needs VPC and subnets
- IAM IRSA roles need EKS OIDC provider URL
- EKS addons need IRSA role ARNs
- Circular dependency: EKS ← → IAM

**The Solution:**
1. **Stage 1:** Create networking (no dependencies)
2. **Stage 2:** Create EKS cluster (uses networking outputs)
3. **Stage 3:** Create IAM roles (uses EKS OIDC URL)
4. **Stage 4:** Install EKS addons (uses IAM role ARNs)

**Benefits:**
- ✅ No circular dependencies
- ✅ No complex mocks or dummy values
- ✅ Clear dependency chain
- ✅ Can update single stage independently
- ✅ Easier to troubleshoot

---

### Terraform State Management

```mermaid
graph LR
    subgraph "Developer/CI"
        TF[Terraform/Terragrunt]
    end

    subgraph "AWS S3"
        BUCKET[S3 State Bucket<br/>tekmetric-terraform-state-*]
        STATE1[environments/dev/<br/>1-networking/terraform.tfstate]
        STATE2[environments/dev/<br/>2-eks-cluster/terraform.tfstate]
        STATE3[environments/dev/<br/>3-iam/terraform.tfstate]
        STATE4[environments/dev/<br/>4-eks-addons/terraform.tfstate]
    end

    subgraph "AWS DynamoDB"
        TABLE[Locks Table<br/>tekmetric-terraform-locks-*]
        LOCK1[Lock: networking]
        LOCK2[Lock: eks-cluster]
        LOCK3[Lock: iam]
        LOCK4[Lock: eks-addons]
    end

    TF -->|read/write state| BUCKET
    TF -->|acquire lock| TABLE

    BUCKET --> STATE1
    BUCKET --> STATE2
    BUCKET --> STATE3
    BUCKET --> STATE4

    TABLE --> LOCK1
    TABLE --> LOCK2
    TABLE --> LOCK3
    TABLE --> LOCK4
```

**State Management Features:**
- **Remote State:** S3 bucket per AWS account
- **State Locking:** DynamoDB prevents concurrent modifications
- **Encryption:** S3 bucket encryption at rest
- **Versioning:** S3 versioning enabled for state recovery
- **Per-Stage State:** Each stage has independent state file
- **Per-Environment:** Separate states for dev, qa, prod

---

## 5. Application Deployment Architecture

### Helm Chart Structure

```mermaid
graph TB
    subgraph "backend-service Chart"
        CHART[Chart.yaml<br/>version: 0.1.0]
        VALUES[values.yaml<br/>Production defaults]
        VALUES_DEV[values-dev.yaml<br/>Dev overrides]
    end

    subgraph "tekmetric-common-chart<br/>(Library Chart)"
        DEPLOYMENT[templates/deployment.yaml]
        SERVICE[templates/service.yaml]
        HPA[templates/hpa.yaml]
        PDB[templates/pdb.yaml]
        SA[templates/serviceaccount.yaml]
        INGRESS[templates/ingress.yaml]

        HELPERS["Helper Templates:<br/>_names.tpl<br/>_labels.tpl<br/>_environment.tpl<br/>_observability.tpl"]
    end

    subgraph "Kubernetes Resources"
        K8S_DEPLOY[Deployment]
        K8S_SVC[Service]
        K8S_HPA[HPA]
        K8S_PDB[PDB]
        K8S_SA[ServiceAccount]
        K8S_ING[Ingress]
        K8S_CM[ConfigMap]
    end

    CHART -->|depends on| DEPLOYMENT
    VALUES --> DEPLOYMENT
    VALUES_DEV --> DEPLOYMENT

    DEPLOYMENT --> HELPERS
    SERVICE --> HELPERS
    HPA --> HELPERS
    PDB --> HELPERS
    SA --> HELPERS
    INGRESS --> HELPERS

    DEPLOYMENT --> K8S_DEPLOY
    SERVICE --> K8S_SVC
    HPA --> K8S_HPA
    PDB --> K8S_PDB
    SA --> K8S_SA
    INGRESS --> K8S_ING

    HELPERS --> K8S_CM
```

**Chart Pattern Benefits:**
- **DRY:** One common chart, multiple services
- **Consistency:** All services deploy the same way
- **Maintainable:** Update once, affects all services
- **Production-Ready:** Built-in best practices

---

### Kubernetes Deployment Flow

```mermaid
sequenceDiagram
    participant H as Helm
    participant K as Kubernetes API
    participant C as Controller
    participant N as Node
    participant P as Pod
    participant S as Service

    H->>K: helm upgrade --install backend
    K->>K: Validate manifests
    K->>C: Create/Update Deployment
    C->>C: Calculate desired state

    alt New Deployment
        C->>N: Schedule pod on node
        N->>P: Start pod
    else Rolling Update
        C->>N: Start new pod (maxSurge: 1)
        N->>P: Start new pod
        P->>P: Run startup probe (max 5 min)
        P->>P: Run readiness probe
        P-->>S: Pod ready, add to endpoints
        C->>N: Terminate old pod (gracefully)
        N->>P: Send SIGTERM (30s grace period)
        P->>P: Finish in-flight requests
        P-->>S: Remove from endpoints
        N->>P: Send SIGKILL if still running
    end

    P->>P: Liveness probe every 10s
    P->>P: Readiness probe every 10s

    S->>P: Route traffic to ready pods
```

**Deployment Guarantees:**
- **Zero Downtime:** maxUnavailable: 0
- **Gradual Rollout:** maxSurge: 1 (one extra pod during update)
- **Health Checks:** Startup, liveness, readiness probes
- **Graceful Shutdown:** 30-second termination grace period
- **Automatic Rollback:** --atomic flag rolls back on failure

---

## 6. Observability Architecture

### Current Implementation

```mermaid
graph TB
    subgraph "Application"
        APP[Backend Service<br/>Spring Boot]
        ACTUATOR[Spring Boot Actuator]
        OTEL[OpenTelemetry Agent<br/>v1.32.0]
    end

    subgraph "Kubernetes"
        POD[Pod<br/>stdout/stderr]
        SVC[Service]
        ANNOTATIONS[Pod Annotations<br/>prometheus.io/*]
        FLUENT[Fluent Bit DaemonSet<br/>CloudWatch Observability Add-on]
    end

    subgraph "AWS Managed Services"
        AMP["AWS Managed Prometheus (AMP)<br/>Metrics storage & alerting"]
        AMG["AWS Managed Grafana (AMG)<br/>Visualization & dashboards"]
        CW_LOGS[CloudWatch Logs<br/>/aws/containerinsights/]
        CW_CONTROL[CloudWatch Logs<br/>EKS Control Plane]
        FLOW_LOGS[VPC Flow Logs]
    end

    subgraph "Prometheus Agent (Deployed)"
        PROM_AGENT[Prometheus Agent<br/>Scrapes metrics]
    end

    APP --> ACTUATOR
    APP --> OTEL
    ACTUATOR -->|/actuator/health| POD
    ACTUATOR -->|/actuator/metrics| POD
    ACTUATOR -->|/actuator/prometheus| POD

    POD -->|logs to stdout| FLUENT
    FLUENT -->|ships logs| CW_LOGS
    POD --> ANNOTATIONS
    POD --> SVC

    ANNOTATIONS -.->|prometheus.io annotations| PROM_AGENT
    SVC -->|/actuator/prometheus| PROM_AGENT
    PROM_AGENT -->|remote_write| AMP
    AMP --> AMG

    OTEL -.ready for.-> COLLECTOR["OTEL Collector (Not deployed)"]
```

**Current State:**
- ✅ Spring Boot Actuator enabled
- ✅ Prometheus metrics exposed at `/actuator/prometheus`
- ✅ OpenTelemetry agent integrated (ready for tracing)
- ✅ CloudWatch Observability add-on deployed (Fluent Bit)
- ✅ Pod logs automatically shipped to CloudWatch
- ✅ CloudWatch control plane logging enabled
- ✅ Health probes configured (liveness, readiness, startup)
- ✅ AWS Managed Prometheus (AMP) workspace deployed
- ✅ AWS Managed Grafana (AMG) workspace deployed
- ✅ Grafana datasource configured (AMP with SigV4 auth)
- ✅ Prometheus Agent deployed (scraping metrics → AMP)
- ✅ Alert rules configured in AMP (8 rules)
- ✅ SNS topic for alert notifications
- ⚠️ Grafana dashboards need creation
- ⚠️ OTEL Collector not deployed (traces not collected yet)
- ⚠️ Tracing backend not deployed (Jaeger/Tempo)

---

### Future Complete Stack

```mermaid
graph TB
    subgraph "Application Layer"
        APP[Backend Service]
        ACTUATOR[Actuator Endpoints]
        OTEL_AGENT[OTEL Agent]
    end

    subgraph "Collection Layer"
        PROM[Prometheus]
        OTEL_COL[OTEL Collector]
        LOKI[Loki]
    end

    subgraph "Storage Layer"
        PROM_TSDB[Prometheus TSDB]
        JAEGER[Jaeger]
        LOKI_STORE[Loki Storage]
        CW[CloudWatch]
    end

    subgraph "Visualization Layer"
        GRAFANA[Grafana]
        JAEGER_UI[Jaeger UI]
        CW_INSIGHTS[CloudWatch Insights]
    end

    subgraph "Alerting Layer"
        ALERT_MGR[Alertmanager]
        SLACK[Slack]
        PAGER[PagerDuty]
    end

    APP --> ACTUATOR
    APP --> OTEL_AGENT
    APP -->|logs| LOKI

    ACTUATOR -->|metrics| PROM
    OTEL_AGENT -->|traces| OTEL_COL

    PROM -->|store| PROM_TSDB
    OTEL_COL -->|store| JAEGER
    LOKI -->|store| LOKI_STORE

    PROM_TSDB --> GRAFANA
    JAEGER --> JAEGER_UI
    LOKI_STORE --> GRAFANA
    CW --> CW_INSIGHTS

    PROM --> ALERT_MGR
    ALERT_MGR --> SLACK
    ALERT_MGR --> PAGER
```

**Three Pillars Complete:**
1. **Metrics:** Prometheus → Grafana dashboards
2. **Logs:** Loki → Grafana log explorer
3. **Traces:** OTEL → Jaeger distributed tracing

---

### Metrics Flow

```mermaid
sequenceDiagram
    participant App as Backend Service
    participant Act as Actuator
    participant Prom as Prometheus
    participant Graf as Grafana
    participant Alert as Alertmanager

    App->>Act: Collect metrics
    Note over Act: JVM memory, GC,<br/>HTTP requests, etc.

    loop Every 30s
        Prom->>Act: GET /actuator/prometheus
        Act-->>Prom: Prometheus-formatted metrics
        Prom->>Prom: Store in TSDB
    end

    loop Every 5s
        Graf->>Prom: Query metrics
        Prom-->>Graf: Time-series data
        Graf->>Graf: Render dashboards
    end

    loop Every 1m
        Prom->>Prom: Evaluate alert rules
        alt Alert firing
            Prom->>Alert: Send alert
            Alert->>Alert: Group & deduplicate
            Alert->>Alert: Apply routing rules
            Alert-->>Prom: Slack/PagerDuty notification
        end
    end
```

---

## 7. Security Architecture

### Authentication & Authorization

```mermaid
graph TB
    subgraph "GitHub Actions"
        WORKFLOW[Workflow Run]
        OIDC_TOKEN[OIDC Token<br/>JWT with claims]
    end

    subgraph "AWS IAM"
        OIDC_PROV[OIDC Provider<br/>token.actions.githubusercontent.com]
        GITHUB_ROLE[GitHub Actions Role<br/>Assume role policy]
        TF_ROLE[Terraform Execution Role<br/>Admin permissions]
    end

    subgraph "AWS Resources"
        S3[S3 State Bucket]
        DDB[DynamoDB Locks]
        EKS[EKS Cluster]
        ECR_REG[ECR Registry]
    end

    subgraph "EKS Cluster"
        API_SERVER[API Server]
        IRSA_OIDC[EKS OIDC Provider]
        POD[Backend Pod]
        SA[Service Account<br/>backend-sa]
        IRSA_ROLE[IRSA Role<br/>Pod permissions]
    end

    WORKFLOW -->|1. Get OIDC token| OIDC_TOKEN
    OIDC_TOKEN -->|2. Request credentials| OIDC_PROV
    OIDC_PROV -->|3. Validate token| GITHUB_ROLE
    GITHUB_ROLE -->|4. Return temporary creds| WORKFLOW
    WORKFLOW -->|5. Assume| TF_ROLE

    TF_ROLE -->|Access| S3
    TF_ROLE -->|Access| DDB
    TF_ROLE -->|Access| EKS
    TF_ROLE -->|Access| ECR_REG

    POD -->|Use| SA
    SA -->|Assume| IRSA_OIDC
    IRSA_OIDC -->|Validate| IRSA_ROLE
    IRSA_ROLE -->|Access AWS services| API_SERVER
```

**Security Benefits:**
- **No Long-Lived Credentials:** Temporary tokens only
- **Scoped Permissions:** GitHub Actions role limited to CI/CD
- **Pod-Level Permissions:** IRSA for granular AWS access
- **Automatic Rotation:** Credentials expire automatically
- **Audit Trail:** CloudTrail logs all API calls

---

### Network Security

```mermaid
graph TB
    subgraph "Internet"
        USER[User]
        ATTACKER[Potential Attacker]
    end

    subgraph "Public Subnets"
        IGW[Internet Gateway]
        NAT[NAT Gateway]
        LB[Load Balancer<br/>Future]
    end

    subgraph "Private Subnets"
        subgraph "EKS Nodes"
            NODE1[Node 1]
            NODE2[Node 2]
        end

        subgraph "Security Groups"
            SG_NODE[Node SG<br/>Allow only required ports]
            SG_POD[Pod SG<br/>Deny by default]
        end
    end

    subgraph "Egress Only"
        ECR[ECR<br/>VPC Endpoint]
        S3[S3<br/>VPC Endpoint]
    end

    USER -->|HTTPS| IGW
    IGW --> LB
    LB --> NODE1
    LB --> NODE2

    ATTACKER -.X.-> NAT
    ATTACKER -.X.-> NODE1

    NODE1 --> NAT
    NODE2 --> NAT
    NAT --> IGW

    NODE1 --> ECR
    NODE2 --> ECR
    NODE1 --> S3
    NODE2 --> S3

    SG_NODE -.restrict.-> NODE1
    SG_NODE -.restrict.-> NODE2
    SG_POD -.restrict.-> NODE1
    SG_POD -.restrict.-> NODE2
```

**Security Layers:**
1. **Network Isolation:** Nodes in private subnets (no direct internet access)
2. **Security Groups:** Least privilege access between components
3. **VPC Endpoints:** Traffic to AWS services stays within AWS network
4. **NACLs:** Additional network-level firewall (optional)
5. **Pod Security:** Non-root containers, dropped capabilities

---

### Container Security

```mermaid
graph TB
    subgraph "Base Image"
        ALPINE[Alpine Linux<br/>Minimal attack surface]
    end

    subgraph "Build Process"
        MULTISTAGE[Multi-stage Build<br/>Remove build tools]
        SCAN[Trivy Scan<br/>Vulnerability detection]
    end

    subgraph "Runtime Security"
        NONROOT[Non-root User<br/>UID 1000]
        READONLY[Read-only Root FS<br/>Where possible]
        CAPS[Dropped Capabilities<br/>ALL dropped]
        SECCOMP[Seccomp Profile<br/>Restrict syscalls]
    end

    subgraph "Kubernetes Security"
        PSS[Pod Security Standards]
        NP[Network Policies<br/>Future]
        SA_TOKEN[Service Account Tokens<br/>Auto-rotated]
    end

    ALPINE --> MULTISTAGE
    MULTISTAGE --> SCAN
    SCAN --> NONROOT

    NONROOT --> READONLY
    READONLY --> CAPS
    CAPS --> SECCOMP

    SECCOMP --> PSS
    PSS --> NP
    NP --> SA_TOKEN
```

**Security Measures:**
- ✅ Alpine Linux base (minimal)
- ✅ Multi-stage builds
- ✅ Trivy security scanning
- ✅ Non-root user (UID 1000)
- ✅ Dropped capabilities
- ✅ Security contexts in Helm
- ⏳ Network policies (future)
- ⏳ Seccomp profiles (future)

---

## 8. Cost Optimization

### Cost Breakdown (Monthly)

```mermaid
pie title Development Environment Costs
    "EKS Control Plane" : 72
    "NAT Gateway" : 32
    "EC2 Nodes (2x t3.medium)" : 60
    "EBS Volumes" : 10
    "Data Transfer" : 6
```

**Dev/QA Environment: ~$180/month**
- EKS Control Plane: $72 (fixed)
- NAT Gateway: $32 (1 NAT)
- EC2 Nodes: $60 (2x t3.medium)
- Storage: $10 (EBS volumes)
- Data Transfer: $6 (estimate)

**Production Environment: ~$520/month**
- EKS Control Plane: $72 (fixed)
- NAT Gateways: $96 (3 NAT, one per AZ)
- EC2 Nodes: $300 (5x t3.large)
- Storage: $30 (EBS volumes)
- Data Transfer: $22 (estimate)

---

### Cost Optimization Strategies

```mermaid
graph TB
    START[Current Cost<br/>~$180/month dev]

    STOP[Stop Workflow<br/>Scale to 0]
    SAVE1[Save 50%<br/>~$90/month]

    DESTROY[Destroy Workflow<br/>Delete all resources]
    SAVE2[Save 100%<br/>$0/month]

    SPOT[Spot Instances<br/>For dev/qa nodes]
    SAVE3[Save 60-70%<br/>~$72/month]

    KARPENTER[Karpenter<br/>Right-sizing + scaling]
    SAVE4[Save 30-40%<br/>~$126/month]

    START --> STOP
    START --> DESTROY
    START --> SPOT
    START --> KARPENTER

    STOP --> SAVE1
    DESTROY --> SAVE2
    SPOT --> SAVE3
    KARPENTER --> SAVE4
```

**Implemented:**
- ✅ Stop/Start workflows (save 50%)
- ✅ Single NAT in dev (save $32/month vs 3 NATs)
- ✅ Smaller instances in dev (t3.medium vs t3.large)
- ✅ Destroy workflow for complete teardown

**Future Optimizations:**
- ⏳ Spot instances for dev/qa (60-70% savings)
- ⏳ Karpenter for intelligent scaling
- ⏳ S3 lifecycle policies for old charts
- ⏳ CloudWatch log retention policies

---

## 9. Disaster Recovery

### Backup Strategy

```mermaid
graph TB
    subgraph "Source of Truth"
        GIT[Git Repository<br/>Infrastructure Code]
    end

    subgraph "State Backups"
        S3_STATE[S3 State Bucket<br/>Versioned]
        S3_BACKUP[S3 Backups Prefix<br/>backups/timestamp/]
    end

    subgraph "Application Artifacts"
        ECR[ECR Images<br/>Immutable tags]
        S3_HELM[S3 Helm Charts<br/>Versioned]
    end

    subgraph "Data (Future)"
        RDS_SNAP[RDS Snapshots<br/>Automated daily]
        RDS_PITR[RDS Point-in-Time<br/>5 min granularity]
    end

    subgraph "Kubernetes Backup (Future)"
        VELERO[Velero<br/>Cluster backup/restore]
        S3_VELERO[S3 Velero Bucket<br/>Backup storage]
    end

    GIT -.recreate.-> S3_STATE
    S3_STATE --> S3_BACKUP

    ECR -.pull.-> DEPLOY[Redeploy]
    S3_HELM -.pull.-> DEPLOY

    RDS_SNAP -.restore.-> NEW_RDS[New RDS]
    RDS_PITR -.restore.-> NEW_RDS

    VELERO --> S3_VELERO
    S3_VELERO -.restore.-> NEW_CLUSTER[New Cluster]
```

**Recovery Scenarios:**

**1. Lost Infrastructure (Account compromised):**
- **RTO:** 30 minutes
- **RPO:** 0 (infrastructure as code)
- **Process:**
  1. Create new AWS account
  2. Run bootstrap Terraform
  3. Deploy staged infrastructure
  4. Redeploy applications

**2. Accidental Resource Deletion:**
- **RTO:** 5-10 minutes
- **RPO:** Last Terraform apply
- **Process:**
  1. terraform plan (review what's missing)
  2. terraform apply (recreate resources)

**3. Database Corruption (Future with RDS):**
- **RTO:** 15-30 minutes
- **RPO:** 5 minutes (point-in-time recovery)
- **Process:**
  1. Identify corruption time
  2. Restore from snapshot before corruption
  3. Point-in-time recovery to exact timestamp
  4. Update application config

**4. Complete EKS Cluster Loss:**
- **RTO:** 20-30 minutes
- **RPO:** Last deployment
- **Process:**
  1. Deploy EKS via Terraform
  2. Redeploy applications via Helm
  3. Verify health checks

---

## 10. Scaling Considerations

### Horizontal Scaling

```mermaid
graph LR
    subgraph "Low Traffic"
        POD1[Pod 1]
        HPA1[HPA<br/>minReplicas: 2]
    end

    subgraph "Medium Traffic"
        POD2A[Pod 1]
        POD2B[Pod 2]
        POD2C[Pod 3]
        HPA2[HPA<br/>CPU: 60%]
    end

    subgraph "High Traffic"
        POD3A[Pod 1]
        POD3B[Pod 2]
        POD3C[Pod 3]
        POD3D[Pod 4]
        POD3E[Pod 5]
        HPA3[HPA<br/>maxReplicas: 10]
    end

    POD1 -->|Traffic increases| POD2A
    POD2A -->|Traffic increases| POD3A
    POD3A -->|Traffic decreases| POD2A
    POD2A -->|Traffic decreases| POD1
```

**HPA Configuration:**
```yaml
autoscaling:
  enabled: true
  minReplicas: 2           # Always 2 pods minimum
  maxReplicas: 10          # Scale up to 10 pods
  targetCPU: 70            # Scale when CPU > 70%
  targetMemory: 80         # Scale when memory > 80%
```

---

### Cluster Autoscaling

```mermaid
graph TB
    subgraph "Initial State"
        NODE1[Node 1<br/>60% utilized]
        NODE2[Node 2<br/>55% utilized]
    end

    subgraph "High Pod Demand"
        POD_PENDING[Pending Pods<br/>Cannot schedule]
    end

    subgraph "Cluster Autoscaler Action"
        CA[Cluster Autoscaler]
        ASG[Auto Scaling Group]
    end

    subgraph "Scaled State"
        NODE3[Node 1]
        NODE4[Node 2]
        NODE5[Node 3<br/>NEW]
        NODE6[Node 4<br/>NEW]
    end

    POD_PENDING -->|Detects| CA
    CA -->|Scales| ASG
    ASG -->|Adds nodes| NODE5
    ASG -->|Adds nodes| NODE6
```

**Cluster Autoscaler:**
- Monitors for pending pods
- Adds nodes when pods can't be scheduled
- Removes underutilized nodes after 10 minutes
- Respects Pod Disruption Budgets

---

## Summary

This architecture demonstrates production-ready practices:
- **Modularity:** Reusable Terraform modules
- **Isolation:** Multi-account setup
- **Security:** OIDC, IRSA, security contexts
- **Reliability:** HA, health checks, graceful shutdown
- **Observability:** Metrics, logs, traces (framework)
- **Cost Optimization:** Stop/start, right-sizing
- **Automation:** Complete CI/CD pipeline
- **Disaster Recovery:** Infrastructure as code, backups

All diagrams are rendered using Mermaid for easy updates and version control.

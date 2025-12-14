# Networking Module

This module creates a complete VPC networking infrastructure for EKS clusters.

## Purpose

Creates a production-ready VPC with:
- Public and private subnets across multiple availability zones
- NAT Gateways for private subnet internet access
- Security groups for EKS cluster and nodes
- VPC endpoints for AWS services (S3, ECR)
- VPC Flow Logs for network monitoring

## Architecture

```
VPC (10.x.0.0/16)
├── Public Subnets (10.x.101.0/24, 10.x.102.0/24, 10.x.103.0/24)
│   ├── Internet Gateway
│   └── NAT Gateways (1 or 3 depending on config)
└── Private Subnets (10.x.1.0/24, 10.x.2.0/24, 10.x.3.0/24)
    ├── EKS Nodes
    └── Route to NAT Gateway
```

## Resources Created

### Core Networking
- **VPC**: Main network with DNS support
- **Internet Gateway**: For public subnet internet access
- **Subnets**: 3 public + 3 private across availability zones
- **NAT Gateways**: 1 (dev/qa) or 3 (prod) for private subnet egress
- **Route Tables**: Public and private with appropriate routes
- **Elastic IPs**: For NAT Gateways

### Security Groups
- **EKS Cluster SG**: Control plane security
  - Ingress: Port 443 from nodes
  - Egress: All traffic
- **EKS Nodes SG**: Worker node security
  - Ingress: All from other nodes, 1025-65535 from control plane
  - Egress: All traffic
- **VPC Endpoints SG**: Endpoints security
  - Ingress: Port 443 from VPC CIDR
  - Egress: All traffic

### VPC Endpoints (Optional)
- **S3**: Gateway endpoint for S3 access
- **ECR API**: Interface endpoint for ECR API
- **ECR DKR**: Interface endpoint for Docker registry

### Monitoring
- **VPC Flow Logs**: CloudWatch logging of network traffic
- **IAM Role**: For Flow Logs to write to CloudWatch

## Usage

```hcl
module "networking" {
  source = "../../../terraform/modules/networking"

  environment          = "dev"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  # Cost optimization for dev/qa
  single_nat_gateway = true

  # Enable best practices
  enable_dns_hostnames = true
  enable_flow_logs     = true
  enable_vpc_endpoints = true

  tags = {
    Project = "tekmetric"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name | string | - | yes |
| vpc_cidr | VPC CIDR block | string | - | yes |
| availability_zones | List of AZs | list(string) | - | yes |
| private_subnet_cidrs | Private subnet CIDRs | list(string) | - | yes |
| public_subnet_cidrs | Public subnet CIDRs | list(string) | - | yes |
| single_nat_gateway | Use single NAT (cost opt) | bool | false | no |
| enable_nat_gateway | Enable NAT Gateways | bool | true | no |
| enable_dns_hostnames | Enable DNS hostnames | bool | true | no |
| enable_dns_support | Enable DNS support | bool | true | no |
| enable_flow_logs | Enable VPC Flow Logs | bool | true | no |
| flow_logs_retention_days | Flow logs retention | number | 7 | no |
| enable_vpc_endpoints | Enable VPC endpoints | bool | true | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| private_subnet_ids | Private subnet IDs |
| public_subnet_ids | Public subnet IDs |
| nat_gateway_ids | NAT Gateway IDs |
| nat_gateway_ips | NAT Gateway public IPs |
| eks_cluster_security_group_id | EKS cluster SG ID |
| eks_nodes_security_group_id | EKS nodes SG ID |
| s3_vpc_endpoint_id | S3 VPC endpoint ID |

## Environment-Specific Configuration

### Development/QA
```hcl
vpc_cidr           = "10.0.0.0/16"  # Dev
# OR
vpc_cidr           = "10.1.0.0/16"  # QA

single_nat_gateway = true  # Cost optimization
enable_flow_logs   = true  # Keep for debugging
flow_logs_retention_days = 7
```

### Production
```hcl
vpc_cidr           = "10.2.0.0/16"

single_nat_gateway = false  # HA with NAT per AZ
enable_flow_logs   = true
flow_logs_retention_days = 30
```

## CIDR Allocation Strategy

Recommended CIDR allocation per environment:

| Environment | VPC CIDR | Private Subnets | Public Subnets |
|-------------|----------|-----------------|----------------|
| Dev | 10.0.0.0/16 | 10.0.1-3.0/24 | 10.0.101-103.0/24 |
| QA | 10.1.0.0/16 | 10.1.1-3.0/24 | 10.1.101-103.0/24 |
| Prod | 10.2.0.0/16 | 10.2.1-3.0/24 | 10.2.101-103.0/24 |

This provides:
- 65,536 IPs per environment
- 762 usable IPs per private subnet (sufficient for 200+ pods per AZ)
- 762 usable IPs per public subnet (for ALBs, NAT gateways)

## Kubernetes Integration

The module automatically tags subnets for Kubernetes:

- **Public Subnets**: `kubernetes.io/role/elb = 1`
  - Used by Kubernetes for creating public load balancers
- **Private Subnets**: `kubernetes.io/role/internal-elb = 1`
  - Used by Kubernetes for creating internal load balancers

## Cost Estimates

### Development/QA (Single NAT)
- VPC: Free
- NAT Gateway: ~$32/month ($0.045/hour)
- NAT Gateway Data: ~$0.045/GB
- VPC Endpoints: ~$7/month ($0.01/hour × 1 endpoint)
- Elastic IP: Free (in use)
- **Total**: ~$40-50/month

### Production (3 NAT Gateways)
- VPC: Free
- NAT Gateways (3): ~$96/month
- NAT Gateway Data: ~$0.045/GB × 3
- VPC Endpoints: ~$21/month (3 endpoints)
- Elastic IPs: Free (in use)
- **Total**: ~$120-150/month

## Security Considerations

### Security Groups
- **Least Privilege**: Only necessary ports open
- **Node-to-Node**: Unrestricted for Kubernetes CNI
- **Control Plane**: Only port 443 from nodes
- **No SSH**: Use AWS Systems Manager Session Manager instead

### Network Segmentation
- **Private Subnets**: For EKS nodes (no direct internet)
- **Public Subnets**: For load balancers only
- **VPC Endpoints**: Keep traffic within AWS network

### Flow Logs
- Enable in all environments
- Retention: 7 days (dev/qa), 30 days (prod)
- Use for security investigation and troubleshooting

## High Availability

### Production Configuration
- **3 Availability Zones**: us-east-1a, us-east-1b, us-east-1c
- **NAT per AZ**: Failure of one AZ doesn't affect others
- **Subnet Distribution**: Spread resources across AZs

### Development/QA Configuration
- **3 Availability Zones**: For cluster HA
- **Single NAT Gateway**: Cost optimization, acceptable downtime
- **Manual Failover**: Recreate NAT in different AZ if needed

## Troubleshooting

### NAT Gateway Connectivity Issues
```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways \
  --filter "Name=vpc-id,Values=vpc-xxxxx"

# Check route tables
aws ec2 describe-route-tables \
  --filters "Name=vpc-id,Values=vpc-xxxxx"

# Test from instance in private subnet
curl -I https://www.google.com
```

### VPC Endpoint Issues
```bash
# Check endpoint status
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-xxxxx"

# Test ECR access
aws ecr get-login-password --region us-east-1
```

### Security Group Debugging
```bash
# List security groups
aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=vpc-xxxxx"

# Check security group rules
aws ec2 describe-security-group-rules \
  --filter "Name=group-id,Values=sg-xxxxx"
```

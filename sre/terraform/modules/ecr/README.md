# ECR Module

Creates and manages Amazon ECR (Elastic Container Registry) repositories for storing container images.

## Features

- ECR repositories with AES256 encryption
- Vulnerability scanning on push
- Lifecycle policies for image retention
- Cross-account access for GitHub Actions OIDC
- Tag-based image retention

## Usage

```hcl
module "ecr" {
  source = "../../modules/ecr"

  repository_names = ["backend"]
  max_image_count  = 10
  scan_on_push     = true

  github_actions_role_arns = [
    "arn:aws:iam::123456789012:role/GitHubActionsRole-dev"
  ]

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| repository_names | List of ECR repository names | list(string) | ["backend"] |
| image_tag_mutability | Image tag mutability (MUTABLE or IMMUTABLE) | string | "MUTABLE" |
| scan_on_push | Enable vulnerability scanning on push | bool | true |
| max_image_count | Max tagged images to keep | number | 10 |
| untagged_expire_days | Days before untagged images expire | number | 7 |
| github_actions_role_arns | GitHub Actions IAM role ARNs | list(string) | [] |
| tags | Tags to apply to all resources | map(string) | {} |

## Outputs

| Name | Description |
|------|-------------|
| repository_urls | Map of repository names to URLs |
| repository_arns | Map of repository names to ARNs |
| registry_id | AWS Account ID (registry ID) |
| registry_url | Full ECR registry URL |

## Lifecycle Policy

Images are automatically managed:
- Keep last 10 tagged images (configurable)
- Remove untagged images after 7 days (configurable)
- Only expires images with numeric or versioned tags (v*, 0-9*)

## Security

- AES256 encryption at rest
- Vulnerability scanning on push (integrates with AWS Security Hub)
- Repository policies enforce least-privilege access
- Only GitHub Actions OIDC roles can push/pull images

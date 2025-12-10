# Bootstrap Module

This module creates the foundational infrastructure required for Terraform state management in AWS.

## Purpose

The bootstrap module is a **one-time setup per AWS account** that creates:
- S3 bucket for storing Terraform state files
- DynamoDB table for state locking
- IAM roles for Terraform execution and state access

## Resources Created

### S3 Bucket
- **Name**: `tekmetric-terraform-state-{account-id}`
- **Versioning**: Enabled (with 30-day lifecycle)
- **Encryption**: AES-256 (default) or KMS (optional)
- **Public Access**: Blocked
- **Lifecycle Policy**: Deletes old versions after configurable days

### DynamoDB Table
- **Name**: `tekmetric-terraform-locks-{account-id}`
- **Billing**: Pay-per-request
- **Hash Key**: LockID (String)
- **Point-in-time Recovery**: Enabled for production
- **Encryption**: Server-side encryption enabled

### IAM Roles
- **TerraformExecution**: Role for applying Terraform changes
  - Full access to EC2, EKS, IAM, KMS (region-restricted)
- **TerraformStateAccess**: Role for reading state (read-only)
  - S3 GetObject/ListBucket
  - DynamoDB GetItem/PutItem/DeleteItem

## Usage

### Initial Setup (Manual)

This module must be applied **before** using Terragrunt for other infrastructure.

```bash
cd sre/terraform/modules/bootstrap

# Initialize Terraform
terraform init

# Plan the changes
terraform plan \
  -var="environment=dev" \
  -var="account_id=123456789012" \
  -var="region=us-east-1"

# Apply the changes (this will use LOCAL state initially)
terraform apply \
  -var="environment=dev" \
  -var="account_id=123456789012" \
  -var="region=us-east-1"
```

**IMPORTANT: After First Apply**

After the first `terraform apply` creates the S3 bucket and DynamoDB table, you **must** migrate the local state to S3:

1. Create a `backend.tf` file:
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "tekmetric-terraform-state-123456789012"
       key            = "bootstrap/terraform.tfstate"
       region         = "us-east-1"
       dynamodb_table = "tekmetric-terraform-locks-123456789012"
       encrypt        = true
     }
   }
   ```

2. Migrate the state:
   ```bash
   terraform init -migrate-state
   ```

3. Verify the state was moved:
   ```bash
   aws s3 ls s3://tekmetric-terraform-state-123456789012/bootstrap/
   ```

4. Delete local state files (they're now in S3):
   ```bash
   rm terraform.tfstate*
   ```

5. **Never commit `*.tfstate` files to git** - ensure they're in `.gitignore`

### With Terragrunt

```hcl
terraform {
  source = "../../../../terraform/modules/bootstrap"
}

inputs = {
  environment               = "dev"
  account_id                = "123456789012"
  region                    = "us-east-1"
  enable_kms_encryption     = false
  enable_mfa_delete         = false
  versioning_lifecycle_days = 30
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name (dev, qa, prod) | string | - | yes |
| account_id | AWS Account ID | string | - | yes |
| region | AWS Region | string | us-east-1 | no |
| state_bucket_prefix | Prefix for state bucket name | string | tekmetric-terraform-state | no |
| lock_table_prefix | Prefix for lock table name | string | tekmetric-terraform-locks | no |
| enable_versioning | Enable S3 versioning | bool | true | no |
| versioning_lifecycle_days | Days to keep old versions | number | 30 | no |
| enable_kms_encryption | Use KMS instead of AES-256 | bool | false | no |
| enable_mfa_delete | Enable MFA delete (prod only) | bool | false | no |

## Outputs

| Name | Description |
|------|-------------|
| state_bucket_name | S3 bucket name for Terraform state |
| state_bucket_arn | S3 bucket ARN |
| lock_table_name | DynamoDB table name for locking |
| lock_table_arn | DynamoDB table ARN |
| terraform_execution_role_arn | IAM role ARN for Terraform execution |
| terraform_state_access_role_arn | IAM role ARN for state access |
| kms_key_arn | KMS key ARN (if enabled) |

## Post-Setup

After applying this module, you'll need to:

1. **Configure Terragrunt** to use the created S3 bucket and DynamoDB table:
   ```hcl
   remote_state {
     backend = "s3"
     config = {
       bucket         = "tekmetric-terraform-state-123456789012"
       key            = "${path_relative_to_include()}/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "tekmetric-terraform-locks-123456789012"
     }
   }
   ```

2. **Migrate this module's state** to the S3 backend (optional):
   ```bash
   terraform init -migrate-state
   ```

## Security Considerations

- **Encryption**: State files contain sensitive data. Always enable encryption.
- **Access Control**: Limit IAM role assumptions to trusted principals
- **MFA Delete**: Enable for production to prevent accidental deletions
- **Versioning**: Keep old versions for rollback capability
- **Audit Logging**: Enable CloudTrail for state bucket access

## Cost Estimates

### S3 Bucket
- Storage: ~$0.023 per GB-month
- Requests: Minimal for state operations
- Estimated: $1-5/month

### DynamoDB Table
- Pay-per-request pricing
- State locks are short-lived
- Estimated: <$1/month

### Total
- **~$2-6 per month per account**

## Troubleshooting

### State Lock Conflicts
If a lock persists after a failed run:
```bash
# List locks
aws dynamodb scan --table-name tekmetric-terraform-locks-123456789012

# Delete stale lock (use with caution)
aws dynamodb delete-item \
  --table-name tekmetric-terraform-locks-123456789012 \
  --key '{"LockID":{"S":"bucket-name/path/to/state/terraform.tfstate"}}'
```

### Bucket Already Exists
If you need to import an existing bucket:
```bash
terraform import aws_s3_bucket.terraform_state tekmetric-terraform-state-123456789012
terraform import aws_dynamodb_table.terraform_locks tekmetric-terraform-locks-123456789012
```

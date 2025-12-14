# Helm S3 Repository Module
# Provides S3-based Helm chart repository using helm-s3 plugin

# S3 bucket for Helm charts
resource "aws_s3_bucket" "helm_charts" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name      = var.bucket_name
      Component = "HelmRepository"
    }
  )
}

# Enable versioning for chart history
resource "aws_s3_bucket_versioning" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to manage old chart versions
resource "aws_s3_bucket_lifecycle_configuration" "helm_charts" {
  bucket = aws_s3_bucket.helm_charts.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }
}

# IAM policy for Helm S3 operations
data "aws_iam_policy_document" "helm_s3_access" {
  statement {
    sid    = "AllowHelmS3Operations"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = [
      aws_s3_bucket.helm_charts.arn,
      "${aws_s3_bucket.helm_charts.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "helm_s3_access" {
  name        = "${var.environment}-helm-s3-access"
  description = "Allow GitHub Actions to push/pull Helm charts from S3"
  policy      = data.aws_iam_policy_document.helm_s3_access.json

  tags = var.tags
}

# Attach policy to GitHub Actions role
resource "aws_iam_role_policy_attachment" "github_actions_helm_s3" {
  role       = var.github_actions_role_name
  policy_arn = aws_iam_policy.helm_s3_access.arn
}

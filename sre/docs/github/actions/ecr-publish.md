# ECR Publish Action

Tags and pushes pre-built Docker images to Amazon ECR (Elastic Container Registry). This action is designed to work after the `docker-build` action has created a local image.

## Features

- ✅ Uses official AWS ECR Login action (`aws-actions/amazon-ecr-login@v2`)
- ✅ ECR authentication handled automatically with password masking
- ✅ Tags local images with ECR registry path
- ✅ Pushes images to ECR
- ✅ Outputs full image URI for deployment
- ✅ Generates step summary with pull command
- ✅ Supports multi-account ECR registries

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `ecr-registry` | ECR registry URL (e.g., `{account-id}.dkr.ecr.us-east-1.amazonaws.com`) | Yes | - |
| `image-name` | Image name (e.g., backend) | Yes | - |
| `source-tag` | Source image tag (local Docker image) | Yes | - |
| `target-tag` | Target image tag (ECR) | Yes | - |

**Note:** AWS region is determined from the configured AWS credentials (set via `aws-assume-role` action) and embedded in the `ecr-registry` URL.

## Outputs

| Output | Description |
|--------|-------------|
| `image-uri` | Full ECR image URI with registry, name, and tag |

## Prerequisites

This action requires:
1. **AWS Credentials**: Must be configured before calling this action (use `aws-assume-role` action)
2. **Local Image**: Image must exist in local Docker (built by `docker-build` action with `load: true`)
3. **ECR Repository**: Repository must exist in ECR (create via Terraform or AWS CLI)

## Usage

### Basic Usage with docker-build

```yaml
- name: Configure AWS credentials
  uses: ./.github/actions/aws-assume-role
  with:
    environment: dev
    role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
    account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}
    aws-region: us-east-1

- name: Build Docker Image
  id: docker
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: 1.0.0-build.123-abc1234
    platforms: linux/amd64  # Single platform to load locally
    load: true

- name: Publish to ECR
  id: ecr
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
    image-name: backend
    source-tag: 1.0.0-build.123-abc1234
    target-tag: 1.0.0-build.123-abc1234
```

### Conditional Publishing (Only on Push)

```yaml
- name: Build Docker Image
  id: docker
  uses: ./.github/actions/docker-build
  with:
    context: ./backend
    image-name: backend
    image-tag: ${{ steps.version.outputs.version }}
    load: true

- name: Configure AWS credentials
  if: github.event_name == 'push' && github.ref == 'refs/heads/master'
  uses: ./.github/actions/aws-assume-role
  with:
    environment: prod
    role-arn: ${{ secrets.AWS_PROD_ROLE_ARN }}
    account-id: ${{ secrets.AWS_PROD_ACCOUNT_ID }}

- name: Publish to ECR
  if: github.event_name == 'push' && github.ref == 'refs/heads/master'
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_PROD_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
    image-name: backend
    source-tag: ${{ steps.version.outputs.version }}
    target-tag: ${{ steps.version.outputs.version }}
```

### Multiple Tags (Latest + Version)

```yaml
- name: Publish with Version Tag
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
    image-name: backend
    source-tag: 1.0.0-build.123
    target-tag: 1.0.0-build.123

- name: Publish with Latest Tag
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
    image-name: backend
    source-tag: 1.0.0-build.123
    target-tag: latest
```

### Multi-Region Publishing

For multi-region publishing, configure AWS credentials for each region before publishing:

```yaml
- name: Configure AWS credentials for us-east-1
  uses: ./.github/actions/aws-assume-role
  with:
    environment: dev
    role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
    account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}
    aws-region: us-east-1

- name: Publish to us-east-1
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
    image-name: backend
    source-tag: ${{ steps.version.outputs.version }}
    target-tag: ${{ steps.version.outputs.version }}

- name: Configure AWS credentials for us-west-2
  uses: ./.github/actions/aws-assume-role
  with:
    environment: dev
    role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
    account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}
    aws-region: us-west-2

- name: Publish to us-west-2
  uses: ./.github/actions/ecr-publish
  with:
    ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-west-2.amazonaws.com
    image-name: backend
    source-tag: ${{ steps.version.outputs.version }}
    target-tag: ${{ steps.version.outputs.version }}
```

## How It Works

1. **Login to ECR** - Uses official `aws-actions/amazon-ecr-login@v2` action
2. **Tag Image** - Tags local image with ECR registry path
3. **Push Image** - Pushes image to ECR
4. **Output URI** - Sets output with full image URI
5. **Summary** - Generates step summary with pull command

## ECR Registry Format

ECR registry URLs follow this format:
```
{account-id}.dkr.ecr.{region}.amazonaws.com
```

Examples:
- `123456789012.dkr.ecr.us-east-1.amazonaws.com`
- `123456789012.dkr.ecr.eu-west-1.amazonaws.com`

## Authentication

This action uses the official AWS ECR Login action (`aws-actions/amazon-ecr-login@v2`) to authenticate to ECR. This action automatically:
- Retrieves an authentication token from ECR
- Logs Docker into the ECR registry
- Masks the password in logs for security

**Requirements:**
- AWS credentials must be configured (via `aws-assume-role` or environment variables)
- IAM role/user must have `ecr:GetAuthorizationToken` permission
- IAM role/user must have `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload` permissions on the target repository

**Benefits of using the official action:**
- ✅ Maintained by AWS
- ✅ Automatic password masking in logs
- ✅ Handles token expiration edge cases
- ✅ More robust error handling

## IAM Permissions Required

Minimum IAM policy for ECR publishing:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:us-east-1:{account-id}:repository/backend"
    }
  ]
}
```

## Troubleshooting

**"No such image: backend:1.0.0":**
- Ensure `docker-build` action ran successfully
- Verify `load: true` was set in docker-build
- Check that `source-tag` matches the tag used in docker-build
- Run `docker images` to verify local image exists

**"Authentication token expired":**
- ECR tokens expire after 12 hours
- Re-run `aws-assume-role` action
- Ensure AWS credentials are valid

**"Repository does not exist":**
- Create ECR repository first:
  ```bash
  aws ecr create-repository --repository-name backend --region us-east-1
  ```
- Or use Terraform to manage ECR repositories

**"Access Denied" / "Unauthorized":**
- Verify IAM role has ECR push permissions
- Check that `ecr-registry` matches your AWS account ID
- Verify AWS credentials are configured correctly

**"Failed to push: unexpected EOF":**
- Network connectivity issue
- Try re-running the workflow
- Check AWS service health dashboard

## Example Output

The action generates a summary like:

```
## 📤 ECR Publish

**Image URI:** `123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:1.0.0-build.123-abc1234`
**Registry:** `123456789012.dkr.ecr.us-east-1.amazonaws.com`
**Status:** ✅ Published

### 📥 Pull Command
```bash
docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/backend:1.0.0-build.123-abc1234
```
```

## Workflow Integration Pattern

**Recommended CI workflow pattern:**

```yaml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
      should-deploy: ${{ steps.version.outputs.should-deploy }}
    permissions:
      id-token: write
      contents: read
    steps:
      # 1. Build and test application
      - name: Build with Maven
        run: mvn clean package

      # 2. Generate version
      - name: Determine version
        id: version
        run: |
          VERSION="1.0.0-build.${{ github.run_number }}-${GITHUB_SHA::8}"
          echo "version=${VERSION}" >> $GITHUB_OUTPUT

          # Only deploy on certain branches
          if [[ "${{ github.ref }}" == "refs/heads/master" ]]; then
            echo "should-deploy=true" >> $GITHUB_OUTPUT
          else
            echo "should-deploy=false" >> $GITHUB_OUTPUT
          fi

      # 3. Build Docker image (always, even for PRs)
      - name: Build Docker Image
        id: docker
        uses: ./.github/actions/docker-build
        with:
          context: ./backend
          image-name: backend
          image-tag: ${{ steps.version.outputs.version }}
          platforms: ${{ github.event_name == 'pull_request' && 'linux/amd64' || 'linux/amd64,linux/arm64' }}
          load: ${{ github.event_name == 'pull_request' && 'true' || 'false' }}

      # 4. Scan image (always)
      - name: Scan Docker Image
        uses: ./.github/actions/trivy-scan
        with:
          image-ref: ${{ steps.docker.outputs.image-ref }}
          severity: CRITICAL,HIGH

      # 5. Configure AWS (only for deployable branches)
      - name: Configure AWS credentials
        if: steps.version.outputs.should-deploy == 'true' && github.event_name != 'pull_request'
        uses: ./.github/actions/aws-assume-role
        with:
          environment: dev
          role-arn: ${{ secrets.AWS_DEV_ROLE_ARN }}
          account-id: ${{ secrets.AWS_DEV_ACCOUNT_ID }}

      # 6. Publish to ECR (only for deployable branches)
      - name: Publish to ECR
        if: steps.version.outputs.should-deploy == 'true' && github.event_name != 'pull_request'
        uses: ./.github/actions/ecr-publish
        with:
          ecr-registry: ${{ secrets.AWS_DEV_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
          image-name: backend
          source-tag: ${{ steps.version.outputs.version }}
          target-tag: ${{ steps.version.outputs.version }}
```

## Comparison with Alternatives

**This approach (docker-build + ecr-publish):**
- ✅ Clear separation: build vs publish
- ✅ PRs can build/scan without AWS credentials
- ✅ Explicit control over when images are pushed
- ✅ Easy to understand and debug

**Alternative: Combined docker-build-push:**
- ❌ Requires AWS credentials even for PRs
- ❌ More complex conditional logic
- ❌ Harder to test builds without publishing

**Alternative: docker/build-push-action directly:**
- ❌ More verbose configuration
- ❌ Requires manual ECR login step
- ❌ Less reusable across workflows

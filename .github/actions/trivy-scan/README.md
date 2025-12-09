# Trivy Security Scan Action

Scans Docker images for security vulnerabilities with configurable thresholds and comprehensive reporting.

## Features

- ✅ Configurable severity filtering (CRITICAL, HIGH, MEDIUM, LOW)
- ✅ SARIF report generation for GitHub Security tab
- ✅ Flexible exit codes (fail build or continue)
- ✅ Support for private registries
- ✅ Option to ignore unfixed vulnerabilities
- ✅ Artifact upload for scan results
- ✅ Rich summary with vulnerability counts

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `image-ref` | Docker image to scan (full reference) | Yes | - |
| `severity` | Severities to check (comma-separated) | No | `CRITICAL,HIGH` |
| `exit-code` | Exit code when vulns found (0 or 1) | No | `0` |
| `format` | Output format (table, json, sarif) | No | `table` |
| `output-file` | File to write results to | No | `trivy-results.txt` |
| `upload-sarif` | Upload to GitHub Security tab | No | `true` |
| `scan-type` | Scan type (image, fs, config) | No | `image` |
| `ignore-unfixed` | Ignore unfixed vulnerabilities | No | `false` |
| `timeout` | Scan timeout (e.g., 5m, 10m) | No | `10m` |
| `registry-username` | Registry username (for private images) | No | `` |
| `registry-password` | Registry password (for private images) | No | `` |

## Outputs

| Output | Description |
|--------|-------------|
| `vulnerabilities-found` | Whether vulnerabilities were detected |
| `scan-result-file` | Path to the scan result file |

## Usage

### Basic Usage

```yaml
- name: Scan Docker Image
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/backend:1.0.0
```

### Scan Private Image

```yaml
- name: Scan Private Image
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/backend:latest
    registry-username: ${{ github.actor }}
    registry-password: ${{ secrets.GITHUB_TOKEN }}
```

### Fail Build on Vulnerabilities

```yaml
- name: Scan and Fail on Issues
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/backend:1.0.0
    severity: CRITICAL,HIGH
    exit-code: '1'  # Fail the build
```

### Scan Only Critical Issues

```yaml
- name: Scan Critical Only
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/backend:1.0.0
    severity: CRITICAL
    exit-code: '0'
```

### Ignore Unfixed Vulnerabilities

```yaml
- name: Scan Fixable Issues Only
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/backend:1.0.0
    severity: CRITICAL,HIGH
    ignore-unfixed: true
    exit-code: '1'
```

### Disable SARIF Upload

```yaml
- name: Scan Without Security Tab
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/backend:1.0.0
    upload-sarif: false
```

### Scan with Longer Timeout

```yaml
- name: Scan Large Image
  uses: ./.github/actions/trivy-scan
  with:
    image-ref: ghcr.io/myorg/large-app:1.0.0
    timeout: 20m
```

## How It Works

1. **Run Trivy Scanner** - Scans image with specified format
2. **Generate SARIF Report** - Creates security report (if enabled)
3. **Upload to Security Tab** - Publishes to GitHub Security (if enabled)
4. **Parse Results** - Extracts vulnerability information
5. **Display Summary** - Shows vulnerability counts and details
6. **Upload Artifacts** - Saves scan results for later review

## Severity Levels

| Level | Description | Examples |
|-------|-------------|----------|
| `CRITICAL` | Immediately exploitable, severe impact | Remote code execution, authentication bypass |
| `HIGH` | Exploitable with significant impact | SQL injection, XSS, privilege escalation |
| `MEDIUM` | Harder to exploit, moderate impact | Information disclosure, DoS |
| `LOW` | Difficult to exploit, minimal impact | Minor information leaks |
| `UNKNOWN` | Severity not yet determined | New CVEs under review |

**Recommended:** `CRITICAL,HIGH` for production scans.

## Exit Code Strategy

### exit-code: '0' (Continue on Vulnerabilities)
**Use when:**
- Building and scanning PRs
- Want visibility without blocking
- Vulnerabilities are reviewed manually
- Gradual security improvements

```yaml
exit-code: '0'  # Log vulnerabilities but don't fail
```

### exit-code: '1' (Fail on Vulnerabilities)
**Use when:**
- Deploying to production
- Enforcing security policy
- Want to prevent vulnerable deployments
- Security is a hard requirement

```yaml
exit-code: '1'  # Fail build if vulnerabilities found
```

## Ignore Unfixed Vulnerabilities

Some vulnerabilities have no fix available yet.

**ignore-unfixed: false (default)**
- Reports all vulnerabilities
- Shows known issues without fixes
- Good for awareness

**ignore-unfixed: true**
- Only reports fixable vulnerabilities
- Focuses on actionable items
- Good for CI blocking

```yaml
ignore-unfixed: true  # Only fail on fixable issues
exit-code: '1'
```

## GitHub Security Tab Integration

When `upload-sarif: true`:
- ✅ Vulnerabilities appear in Security > Code scanning
- ✅ GitHub creates alerts for each vulnerability
- ✅ Alerts include severity, description, and fix info
- ✅ Can configure alerts and notifications

**Requires:**
- `security-events: write` permission
- GitHub Advanced Security (for private repos)

```yaml
permissions:
  security-events: write
```

## Output Formats

### table (default)
Human-readable table format:
```
Library    | Vulnerability | Severity | Status
-----------|---------------|----------|--------
curl       | CVE-2023-1234 | HIGH     | fixed
openssl    | CVE-2023-5678 | CRITICAL | fixed
```

### json
Machine-readable JSON:
```json
{
  "Results": [
    {
      "Vulnerabilities": [...]
    }
  ]
}
```

### sarif
Security scanning format for GitHub:
- Used for Security tab integration
- Industry standard format
- Tool-agnostic

## Scan Results Artifacts

Results are automatically uploaded as artifacts:
- `trivy-results.txt` - Scan output in specified format
- `trivy-results.sarif` - SARIF report (if generated)
- Retention: 30 days
- Available in workflow run summary

## Requirements

- Image must be accessible (public or authenticated)
- For private images: provide registry credentials
- For SARIF upload: `security-events: write` permission
- Internet connection (for vulnerability database)

## Troubleshooting

**"Failed to download vulnerability DB":**
- Check internet connectivity
- Increase timeout value
- Retry the scan

**"Failed to authenticate to registry":**
- Verify registry-username and registry-password
- Ensure credentials have pull permissions
- Check image-ref is correct

**"Scan timeout":**
- Increase timeout value (e.g., `20m`)
- Image may be very large
- Check network speed

**"No SARIF results in Security tab":**
- Verify `upload-sarif: true`
- Check `security-events: write` permission
- For private repos: need GitHub Advanced Security
- Wait a few minutes for processing

**"Too many vulnerabilities":**
- Use `ignore-unfixed: true` to focus on fixable issues
- Set stricter severity filter (only CRITICAL)
- Update base images to newer versions
- Review and update dependencies

## Best Practices

### For Pull Requests
```yaml
severity: CRITICAL,HIGH
exit-code: '0'  # Don't block PRs, just report
upload-sarif: true
```

### For Production Deployments
```yaml
severity: CRITICAL
exit-code: '1'  # Block vulnerable deployments
ignore-unfixed: true  # Only block on fixable issues
upload-sarif: true
```

### For Security Audits
```yaml
severity: CRITICAL,HIGH,MEDIUM
exit-code: '0'
ignore-unfixed: false  # Show everything
upload-sarif: true
```

## Example Output

The action generates a summary like:

```
## 🔒 Security Scan Results

**Image:** `ghcr.io/myorg/backend:1.0.0`
**Severity Filter:** `CRITICAL,HIGH`
**Ignore Unfixed:** false

### 📋 Scan Output
```
Library    | Vulnerability | Severity | Status
-----------|---------------|----------|--------
curl       | CVE-2023-1234 | HIGH     | fixed
openssl    | CVE-2023-5678 | CRITICAL | fixed
```

**Summary:**
- 🔴 Critical: 1
- 🟠 High: 1

📊 Detailed results available in the Security tab
```

## Comparison with Other Approaches

**This action:**
- Trivy-based (fast, comprehensive)
- Configurable thresholds
- GitHub Security integration
- Flexible reporting

**Alternatives:**
- Snyk (commercial, more features)
- Grype (similar to Trivy)
- Docker Scan (Docker-specific)
- Manual security reviews (slow, inconsistent)

**Our choice:** Trivy provides excellent free scanning with GitHub integration.

## Security Scanning Strategy

1. **Scan on PRs** - Early detection, don't block
2. **Scan on merge** - Fail fast on CRITICAL issues
3. **Scheduled scans** - Weekly scans of production images
4. **Monitor Security tab** - Review and triage alerts
5. **Update regularly** - Keep base images and dependencies current

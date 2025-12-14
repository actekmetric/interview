# Helm Rollback Action

Automatically rolls back Helm releases when deployments fail post-deployment validation. This action integrates with smoke tests and integration tests to catch issues that Helm's atomic deployment can't detect.

## Features

- ✅ Automatic rollback on smoke test failure
- ✅ Checks release history before rollback
- ✅ Handles first deployment edge case (optional uninstall)
- ✅ Configurable timeout and wait options
- ✅ Pod readiness verification after rollback
- ✅ Detailed outputs and status reporting

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `cluster-name` | EKS cluster name (e.g., tekmetric-dev) | Yes | - |
| `aws-region` | AWS region where EKS cluster is located | No | `us-east-1` |
| `release-name` | Helm release name to rollback | Yes | - |
| `namespace` | Kubernetes namespace | No | `default` |
| `revision` | Specific revision to rollback to (leave empty for previous revision) | No | `` |
| `timeout` | Timeout for rollback operation (e.g., 5m) | No | `5m` |
| `wait` | Wait for rollback to complete | No | `true` |
| `cleanup-on-fail` | Cleanup resources on rollback failure | No | `true` |
| `uninstall-if-first` | Uninstall release if this is the first deployment (no previous revision) | No | `true` |

## Outputs

| Output | Description |
|--------|-------------|
| `rollback-status` | Status of rollback operation (success, failed, no-previous-revision, uninstalled) |
| `previous-revision` | Revision number rolled back to |
| `current-revision` | Current revision before rollback |

## Usage

### Basic Usage (CD Workflow)

```yaml
- name: Rollback on Smoke Test Failure
  if: failure() && steps.smoke-tests.outcome == 'failure'
  uses: ./.github/actions/helm-rollback
  with:
    cluster-name: tekmetric-dev
    release-name: backend
    namespace: backend-services
```

### With Custom Timeout

```yaml
- name: Rollback with Extended Timeout
  uses: ./.github/actions/helm-rollback
  with:
    cluster-name: tekmetric-prod
    release-name: backend
    namespace: backend-services
    timeout: 10m
```

### Rollback to Specific Revision

```yaml
- name: Rollback to Known Good Version
  uses: ./.github/actions/helm-rollback
  with:
    cluster-name: tekmetric-qa
    release-name: backend
    namespace: backend-services
    revision: 3  # Specific revision number
```

### Skip Uninstall on First Deployment Failure

```yaml
- name: Rollback (Keep First Deployment)
  uses: ./.github/actions/helm-rollback
  with:
    cluster-name: tekmetric-dev
    release-name: backend
    namespace: backend-services
    uninstall-if-first: false  # Don't uninstall first deployment
```

## How It Works

1. **Configure EKS Access**: Updates kubeconfig for target cluster
2. **Check Release History**:
   - Verifies release exists
   - Gets current revision number
   - Determines if previous revision exists
3. **Perform Rollback**:
   - If revision > 1: Rolls back to previous revision (or specified revision)
   - If revision = 1: Optionally uninstalls the failed first deployment
4. **Verify Rollback**: Waits for pods to be ready after rollback (300s timeout)
5. **Report Status**: Generates GitHub step summary with status and revision info

## Edge Cases

### First Deployment Failure

When a brand new deployment fails (revision 1), there's no previous revision to rollback to.

**Behavior**:
- If `uninstall-if-first: true` (default): Uninstalls the failed release
- If `uninstall-if-first: false`: Skips rollback, leaves failed deployment

**Reason**: Leaves cluster in clean state vs debugging first deployment

### Release Not Found

If the release doesn't exist, the action fails with clear error message.

### Already Rolled Back

If current revision is already 1, the action detects this and handles appropriately.

## Troubleshooting

**Issue**: Rollback times out
**Cause**: Pods taking too long to become ready
**Solution**: Increase `timeout` parameter or investigate pod issues

**Issue**: "No previous revision" error
**Cause**: Attempting to rollback first deployment
**Solution**: Set `uninstall-if-first: true` to clean up, or `false` to keep for debugging

**Issue**: "Release not found"
**Cause**: Release name or namespace incorrect
**Solution**: Verify release exists: `helm list -n <namespace>`

**Issue**: Rollback succeeds but pods still unhealthy
**Cause**: Previous version also has issues
**Solution**: Check Helm history: `helm history <release> -n <namespace>`, may need to rollback further

## Integration with CD Workflow

This action is designed to integrate with smoke tests in CD workflows:

```yaml
jobs:
  deploy:
    steps:
      - name: Deploy to EKS with Helm
        uses: ./.github/actions/helm-deploy
        with:
          cluster-name: tekmetric-dev
          release-name: backend
          # ... other inputs

      - name: Run Smoke Tests
        id: smoke-tests
        run: |
          # Test health endpoints
          # Test application endpoints
          # Exit 1 if any test fails

      - name: Rollback on Failure
        if: failure() && steps.smoke-tests.outcome == 'failure'
        uses: ./.github/actions/helm-rollback
        with:
          cluster-name: tekmetric-dev
          release-name: backend
          namespace: backend-services
```

**Flow**:
1. Helm deploy succeeds (atomic deployment)
2. Smoke tests run against deployed version
3. If smoke tests fail → rollback triggered automatically
4. Cluster returns to previous working state

## Example Output

The action generates a summary like:

```
## 🔄 Helm Rollback Summary

**Release:** `backend`
**Namespace:** `backend-services`
**Cluster:** `tekmetric-dev`

✅ **Status:** Rollback successful
**Revisions:** 3 → 2
```

Or for first deployment:

```
## 🔄 Helm Rollback Summary

**Release:** `backend`
**Namespace:** `backend-services`
**Cluster:** `tekmetric-dev`

🗑️ **Status:** Release uninstalled (first deployment)
```

## Comparison with Helm Atomic Deploys

**Helm's --atomic flag**:
- Rolls back if *deployment itself* fails (e.g., pod crash, health probe failure during rollout)
- Does NOT rollback after deployment succeeds

**This action**:
- Rolls back if *post-deployment validation* fails (smoke tests, integration tests)
- Catches issues that Helm can't detect (broken endpoints, integration failures)

**Use both together**:
```yaml
- name: Deploy
  uses: ./.github/actions/helm-deploy
  with:
    atomic: true  # Helm's atomic rollback

- name: Smoke Tests
  id: smoke-tests
  run: ./smoke-tests.sh

- name: Rollback on Test Failure
  if: failure() && steps.smoke-tests.outcome == 'failure'
  uses: ./.github/actions/helm-rollback  # Application-level rollback
  with:
    cluster-name: tekmetric-dev
    release-name: backend
    namespace: backend-services
```

## Requirements

- AWS credentials must be configured (for EKS access)
- kubectl must be available
- Helm must be installed
- Target EKS cluster must exist

## Safety Features

- **Wait for pods**: Ensures rollback completes before continuing
- **Cleanup on fail**: Removes failed resources during rollback
- **Status outputs**: Allows downstream steps to react to rollback status
- **Detailed logging**: Shows exactly what happened during rollback

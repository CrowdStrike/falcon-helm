# E2E Tests for Falcon Helm Charts

This directory contains end-to-end (e2e) integration tests for the Falcon Helm charts. These tests deploy the charts to a real Kubernetes cluster and verify their functionality.

## Overview

E2E tests use [Terratest](https://terratest.gruntwork.io/) with [Ginkgo v2](https://onsi.github.io/ginkgo/) BDD framework to:
- Deploy Helm charts to a Kubernetes cluster
- Verify resources are created correctly
- Verify pods are running and healthy
- Test chart upgrades and configuration changes
- Clean up resources after tests

## Prerequisites

1. **Kubernetes Cluster**: A running Kubernetes cluster (kind, k3s, minikube, GKE, EKS, AKS, etc.)
2. **kubectl**: Configured to access your cluster
3. **Helm 3.x**: Installed and configured
4. **Go 1.21+**: For running the tests
5. **CrowdStrike CID**: Required for deploying the Falcon sensor

## Running E2E Tests

### Set Required Environment Variables

```bash
# Required: Your CrowdStrike Customer ID (or use API credentials to retrieve it)
export FALCON_CID="1234567890ABCDEF1234567890ABCDEF-12"

# Optional: Specify custom image with full reference (repository:tag)
# If not specified AND API credentials are provided, the latest image will be auto-discovered
export IMG="registry.crowdstrike.com/falcon-sensor/us-1/release/falcon-sensor:7.20.0-16400"

# Optional: Custom kubeconfig path (defaults to ~/.kube/config)
export KUBECONFIG=/path/to/kubeconfig
```

**Image Configuration:**
- If `IMG` is set, it will be used as-is
- If `IMG` is not set but Falcon API credentials are available, the latest sensor image will be auto-discovered from the CrowdStrike registry
- Auto-discovery queries the registry using semantic versioning to find the latest available image
- If neither `IMG` nor API credentials are available, the test will fail

### Registry Authentication (Required)

To pull images from a private registry (including CrowdStrike's registry), you must configure authentication using one of these methods:

#### Method 1: Falcon API Credentials (Recommended for CrowdStrike Registry)

Use your Falcon API credentials to automatically retrieve registry credentials and discover the latest image:

```bash
export FALCON_CLIENT_ID="your-client-id"
export FALCON_CLIENT_SECRET="your-client-secret"
```

The test framework will:
- Authenticate with the Falcon API using your credentials
- Automatically retrieve a registry token
- Generate the proper registry username from your CID
- Create and configure the image pull secret
- **Auto-discover the latest sensor image** if `IMG` is not set (uses semantic versioning)

#### Method 2: Explicit Username and Password

```bash
export REGISTRY_USERNAME="myuser"
export REGISTRY_PASSWORD="mypassword"
export REGISTRY_SERVER="registry.example.com"
```

#### Method 3: Docker Config JSON

```bash
# Use existing Docker credentials
export DOCKER_CONFIG_JSON=$(cat ~/.docker/config.json | base64)

# Or create inline
export DOCKER_CONFIG_JSON='{"auths":{"registry.example.com":{"username":"user","password":"pass","auth":"dXNlcjpwYXNz"}}}'
```

The test framework will:
- Automatically create a Kubernetes image pull secret in the test namespace
- Configure the Helm chart to use the secret
- Clean up the secret when tests complete

### Run Tests Using Makefile

From the repository root:

```bash
# Run falcon-sensor e2e tests with API credentials (auto-discovers latest image)
make e2e-sensor \
  FALCON_CLIENT_ID=$FALCON_CLIENT_ID \
  FALCON_CLIENT_SECRET=$FALCON_CLIENT_SECRET

# Or with explicit CID if you already have it
make e2e-sensor FALCON_CID=$FALCON_CID

# Run with custom image (overrides auto-discovery)
make e2e-sensor \
  FALCON_CLIENT_ID=$FALCON_CLIENT_ID \
  FALCON_CLIENT_SECRET=$FALCON_CLIENT_SECRET \
  IMG=registry.crowdstrike.com/falcon-sensor/us-1/release/falcon-sensor:7.20.0-16400

# Run with verbose output
make e2e-sensor FALCON_CID=$FALCON_CID V=1

# Focus on specific test(s) using Ginkgo focus filter
make e2e-sensor FALCON_CID=$FALCON_CID FOCUS="basic deployment"

# Skip specific test(s) using Ginkgo skip filter
make e2e-sensor FALCON_CID=$FALCON_CID SKIP="upgrade"

# Run with private registry authentication (non-CrowdStrike registry)
make e2e-sensor FALCON_CID=$FALCON_CID \
  IMG=registry.example.com/falcon-sensor:7.20.0-16400 \
  REGISTRY_USERNAME=myuser \
  REGISTRY_PASSWORD=mypassword
```

**Real-Time Test Output**: Tests use Ginkgo's output formatting with color-coded results and progress indicators. Each test spec shows its status (✓ for passed, ✗ for failed) as it runs:

```
Running Suite: Falcon Sensor E2E Suite - /Users/.../falcon-helm/tests/e2e/falcon-sensor
=====================================================================================
Random Seed: 1234567890

Will run 5 of 5 specs
•••••
Ran 5 of 5 Specs in 45.123 seconds
SUCCESS! -- 5 Passed | 0 Failed | 0 Pending | 0 Skipped
```

### Run Tests Directly with Ginkgo

From the repository root:

```bash
# Run all e2e tests with API credentials (auto-discovers latest image)
cd tests/e2e/falcon-sensor && \
  FALCON_CLIENT_ID=$FALCON_CLIENT_ID \
  FALCON_CLIENT_SECRET=$FALCON_CLIENT_SECRET \
  ginkgo -v

# Or with explicit CID
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  ginkgo -v

# Focus on specific test(s)
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  ginkgo -v --focus="basic deployment"

# Skip specific test(s)
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  ginkgo -v --skip="upgrade"

# Run with custom image (overrides auto-discovery)
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  IMG=registry.crowdstrike.com/falcon-sensor/us-1/release/falcon-sensor:7.20.0-16400 \
  ginkgo -v

# Run with private registry authentication
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  IMG=registry.example.com/falcon-sensor:7.20.0-16400 \
  REGISTRY_USERNAME=myuser \
  REGISTRY_PASSWORD=mypassword \
  ginkgo -v

# Parallel execution (run specs in parallel)
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  ginkgo -v -p
```

**Note**: Tests use Ginkgo v2 BDD framework which provides better test organization, filtering, and output formatting compared to standard Go testing.

## Test Structure

```
falcon-helm/
├── go.mod                             # Single Go module for entire project
├── go.sum                             # Go module checksums
├── tests/
│   ├── template/                      # Template rendering tests (fast, no cluster)
│   │   ├── common/
│   │   │   └── constants.go          # Shared test constants
│   │   ├── falcon-kac/
│   │   │   └── deployment_webhook_test.go
│   │   └── falcon-sensor/
│   │       └── daemonset_test.go
│   └── e2e/                           # End-to-end tests (require cluster)
│       ├── README.md                  # This file
│       ├── common/
│       │   ├── test_helpers.go       # Shared test utilities and helpers
│       │   └── falcon_registry.go    # Falcon API and registry operations
│       └── falcon-sensor/
│           ├── falcon_sensor_suite_test.go  # Ginkgo test suite setup
│           └── node_sensor_e2e_test.go      # Test specs
```

**Note**: The project now uses a single `go.mod` file at the repository root, eliminating duplicate dependency management between test suites.

## Available Tests

### Falcon Sensor Tests

Located in `tests/e2e/falcon-sensor/`:

**Test Specs** (using Ginkgo BDD framework):

1. **"deploys node sensor with basic configuration"**
   - Deploys the node sensor as a DaemonSet
   - Verifies deployment on all cluster nodes
   - Checks pod status and container readiness

2. **"deploys node sensor with BPF backend"**
   - Tests deployment with BPF backend
   - Verifies backend environment variables
   - Confirms pods are running correctly

3. **"upgrades node sensor deployment"**
   - Tests Helm chart upgrades
   - Verifies configuration changes propagate
   - Ensures pods remain healthy after upgrade

4. **"deploys node sensor with tolerations"**
   - Tests DaemonSet with tolerations
   - Verifies scheduling on tainted nodes
   - Checks default toleration configuration

5. **"cleans up node sensor resources properly"**
   - Verifies proper resource cleanup
   - Tests uninstallation process

## Test Helpers

The [common/test_helpers.go](common/test_helpers.go) file provides utilities for:

- **TestContext**: Manages test lifecycle, namespaces, and resources
  - Stores test configuration including image, CID, API client, cloud type
  - Provides methods for Helm operations and resource verification
- **Setup/Cleanup**: Automated resource creation and teardown with proper synchronization
  - `setupTest()`: Creates namespace, initializes Falcon API client, creates image pull secret, auto-discovers image if needed
  - `Cleanup()`: Uninstalls Helm release, waits for cleanup DaemonSets to complete, waits for all DaemonSets to be deleted, then deletes namespace
- **DaemonSet Operations**: Wait for readiness, get pods, verify scheduling
  - `WaitForDaemonSetReady()`: Polls until DaemonSet pods are ready and updated
  - `WaitForCleanupDaemonSetComplete()`: Waits for cleanup DaemonSet to finish its work
  - `WaitForAllDaemonSetsDeleted()`: Ensures all DaemonSets are deleted before namespace removal
- **Pod Verification**: Check running status, container readiness
- **Image Configuration**:
  - `GetImageConfig()`: Returns repository and tag from tc.Image or IMG environment variable
  - `SetImageValues()`: Automatically sets image.repository and image.tag in Helm values
- **Registry Authentication**:
  - `CreateImagePullSecret()`: Automatic creation of image pull secrets from Falcon API or environment variables
  - Uses Falcon API credentials to retrieve registry token and generate username
- **Image Auto-Discovery**:
  - `GetLatestSensorImage()`: Queries Docker Registry API v2 to find latest sensor image by semantic version
  - Uses cached Falcon API client for authentication
  - Filters version tags and sorts by semantic version to identify latest release
- **Kubernetes Client**: Simplified access to K8s API

**Test Isolation**: The cleanup process is designed to ensure complete test isolation. After each test:
1. Helm release is uninstalled
2. Cleanup DaemonSet is detected and monitored until completion (up to 2 minutes)
3. All DaemonSets (main and cleanup) are confirmed deleted (up to 2 minutes)
4. Namespace is deleted
5. This prevents resource conflicts and ensures the next test starts with a clean slate

### Example Usage

```go
var _ = Describe("Node Sensor", func() {
    var tc *common.TestContext

    BeforeEach(func() {
        // setupTest creates test context with unique namespace
        // Automatically initializes Falcon API client if credentials available
        // Auto-discovers latest image if IMG not set
        tc = setupTest()
    })

    It("deploys with basic configuration", func() {
        // Install chart with automatic image configuration
        values := map[string]string{
            "falcon.cid": tc.CID,
            "node.enabled": "true",
        }
        // SetImageValues automatically uses tc.Image (from auto-discovery or IMG)
        tc.SetImageValues(values, "node")
        tc.InstallChart(values)

        // Verify deployment using Gomega matchers
        daemonsetName := tc.ReleaseName + "-falcon-sensor"
        tc.WaitForDaemonSetReady(daemonsetName, 60, 10*time.Second)

        pods := tc.GetDaemonSetPods(daemonsetName)
        Expect(pods).NotTo(BeEmpty(), "Should have at least one pod")

        for _, pod := range pods {
            Expect(pod.Status.Phase).To(Equal(corev1.PodRunning))
        }
    })
})
```

## Debugging Tests

### Ginkgo Test Output

Tests use Ginkgo v2 which provides structured output with clear indicators of test progress and failures:

```
Running Suite: Falcon Sensor E2E Suite
======================================

Will run 5 of 5 specs
••S••

Ran 5 of 5 Specs in 45.123 seconds
SUCCESS! -- 4 Passed | 0 Failed | 0 Pending | 1 Skipped

[PASSED] - deploys node sensor with basic configuration [30.5 seconds]
[PASSED] - deploys node sensor with BPF backend [15.2 seconds]
[SKIPPED] - upgrades node sensor deployment
[PASSED] - deploys node sensor with tolerations [12.3 seconds]
[PASSED] - cleans up node sensor resources properly [8.1 seconds]
```

Use `-v` flag for verbose output including all log messages from the test context.

### View Test Output

```bash
# Run with verbose output using Ginkgo
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  ginkgo -v

# Run with even more verbose output
cd tests/e2e/falcon-sensor && \
  FALCON_CID=$FALCON_CID \
  ginkgo -v --trace
```

### Inspect Resources

Tests create unique namespaces with names like `falcon-test-<random-id>`. To inspect resources:

```bash
# List test namespaces
kubectl get namespaces | grep falcon-test

# View resources in a test namespace
kubectl get all -n falcon-test-abc123

# View pod logs
kubectl logs -n falcon-test-abc123 <pod-name>
```

### Preserve Test Resources

To debug test failures, modify the `DeferCleanup` in your test suite to prevent automatic cleanup.

## Best Practices

1. **Use Unique Namespaces**: Each test creates a unique namespace to avoid conflicts
2. **Always Cleanup**: Use `DeferCleanup()` in Ginkgo to ensure resources are removed
3. **Set Timeouts**: Configure appropriate timeouts for cluster operations
4. **Test Isolation**: Tests should not depend on each other
5. **Use Ginkgo Filters**: Use `--focus` and `--skip` flags to run specific tests during development
6. **Auto-Discovery**: When possible, use Falcon API credentials instead of hardcoding image versions
7. **Wait for Cleanup**: The test framework automatically waits for:
   - Helm release uninstallation to complete
   - Cleanup DaemonSets to finish their work (if any)
   - All DaemonSets to be fully deleted
   - This ensures proper test isolation and prevents resource conflicts between tests

## Troubleshooting

### Cleaning Up Orphaned Resources

If tests fail or are interrupted (Ctrl+C), they may leave behind test resources. Use the cleanup script:

```bash
# Dry run - see what would be deleted (no actual deletion)
make clean-e2e-resources-dry-run

# Actually delete orphaned resources older than 60 minutes (default)
make clean-e2e-resources

# Customize age threshold (e.g., 30 minutes)
AGE_THRESHOLD_MINUTES=30 ./tests/e2e/cleanup-test-resources.sh

# Force cleanup of all test namespaces regardless of age
AGE_THRESHOLD_MINUTES=0 ./tests/e2e/cleanup-test-resources.sh
```

The cleanup script will:
- Find all namespaces matching `falcon-test-*` pattern
- Uninstall Helm releases in those namespaces
- Delete the namespaces
- Only delete namespaces older than the age threshold (default: 60 minutes)

### Manual Cleanup

If you need to manually clean up specific test resources:

```bash
# List test namespaces
kubectl get namespaces | grep falcon-test

# Delete a specific namespace
kubectl delete namespace falcon-test-abc123

# Force delete if stuck
kubectl delete namespace falcon-test-abc123 --grace-period=0 --force

# List Helm releases in a test namespace
helm list -n falcon-test-abc123

# Uninstall a specific release
helm uninstall falcon-test-abc123 -n falcon-test-abc123
```

### Tests Hang or Timeout

- Check cluster has sufficient resources
- Verify images can be pulled
- Increase timeout values in test code

### Permission Errors

- Verify kubectl can access the cluster
- Check RBAC permissions for the namespace
- Ensure service account has required permissions

### Image Pull Errors

- Verify image registry is accessible
- Check pull secrets are configured correctly
- Confirm image repository and tag are valid

### Cleanup Issues

If namespaces are stuck in "Terminating" state:

```bash
# Check namespace status
kubectl get namespace falcon-test-abc123 -o yaml

# Check for finalizers blocking deletion
kubectl get namespace falcon-test-abc123 -o json | jq '.spec.finalizers'

# Remove finalizers if safe (be careful!)
kubectl patch namespace falcon-test-abc123 -p '{"spec":{"finalizers":null}}' --type=merge

# Or use the cleanup script which handles force deletion
make clean-e2e-resources
```

### Preventing Resource Leaks

To ensure cleanup happens even if tests fail, the test framework uses `defer tc.Cleanup()` in all tests. However, if you interrupt tests with Ctrl+C or kill the process, cleanup may not run.

**Best Practices:**
1. Let tests complete naturally when possible
2. Run `make clean-e2e-resources-dry-run` periodically to check for orphaned resources
3. Set up a cron job or scheduled task to run cleanup automatically:
   ```bash
   # Add to crontab: cleanup every hour
   0 * * * * cd /path/to/falcon-helm && make clean-e2e-resources
   ```

## Contributing

When adding new e2e tests:

1. Follow existing Ginkgo BDD test patterns
2. Use the `setupTest()` function for test context initialization
3. Add test documentation in `Describe` and `It` blocks
4. Ensure tests are idempotent
5. Handle cleanup properly with `DeferCleanup()`
6. Use Gomega matchers for assertions
7. Test with and without verbose output

## Resources

- [Ginkgo Documentation](https://onsi.github.io/ginkgo/)
- [Gomega Matchers](https://onsi.github.io/gomega/)
- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Kubernetes Go Client](https://github.com/kubernetes/client-go)
- [Helm Documentation](https://helm.sh/docs/)

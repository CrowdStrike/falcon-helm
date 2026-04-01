# Developer Guide

## Requirements

The following need to be installed to develop and test the Helm Operator and the Helm Chart.

* [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [Helm 3.x](https://helm.sh/docs/intro/install/)
* [Go 1.21+](https://golang.org/doc/install) (for running tests)
* [Ginkgo CLI](https://onsi.github.io/ginkgo/) (for running e2e tests) - Install with `make e2e-install`
* A working Kubernetes cluster (for e2e tests)

## Helm Operator

## Helm Charts

### Testing

This repository uses [Terratest](https://terratest.gruntwork.io/) for testing Helm charts. E2E tests use [Ginkgo v2](https://onsi.github.io/ginkgo/) BDD framework for better test organization and output. Tests are located in the `tests/` directory.

#### Template Tests

Template tests validate Helm chart rendering without deploying to a cluster. These are fast and run in CI.

**Running Template Tests:**

Use the Makefile targets to run tests:

```bash
# Show all available test targets
make help

# Run all template tests
make test-all

# Run tests for a specific chart
make test-sensor
make test-kac
```

**Running Template Tests Directly with Go:**

You can also run tests directly using Go from the repository root:

```bash
# Run all template tests
go test ./tests/template/...

# Run tests for a specific chart
go test ./tests/template/falcon-sensor

# Run with verbose output
go test -v ./tests/template/...
```

#### E2E Integration Tests

E2E tests deploy charts to a real Kubernetes cluster and verify functionality using [Ginkgo v2](https://onsi.github.io/ginkgo/) BDD framework. These tests require:
- A running Kubernetes cluster (kind, k3s, minikube, GKE, EKS, AKS)
- kubectl configured with cluster access
- Ginkgo CLI installed (`make e2e-install`)
- CrowdStrike API credentials (for registry authentication and image auto-discovery)

**Installing Ginkgo:**

```bash
# Install Ginkgo CLI (required for e2e tests)
make e2e-install
```

**Running E2E Tests:**

```bash
# Run with API credentials (auto-discovers latest sensor image)
make e2e-sensor \
  FALCON_CLIENT_ID=$FALCON_CLIENT_ID \
  FALCON_CLIENT_SECRET=$FALCON_CLIENT_SECRET

# Run with explicit CID and custom image
export FALCON_CID="1234567890ABCDEF1234567890ABCDEF-12"
export IMG="registry.crowdstrike.com/falcon-sensor/us-1/release/falcon-sensor:7.20.0-16400"
make e2e-sensor FALCON_CID=$FALCON_CID IMG=$IMG

# Run with verbose output
make e2e-sensor FALCON_CID=$FALCON_CID V=1

# Focus on specific test(s)
make e2e-sensor FALCON_CID=$FALCON_CID FOCUS="basic deployment"

# Skip specific test(s)
make e2e-sensor FALCON_CID=$FALCON_CID SKIP="upgrade"
```

**Image Auto-Discovery:**

When `IMG` is not set but Falcon API credentials are provided, the test framework will:
- Authenticate with the Falcon API
- Query the Docker Registry API v2
- Find the latest sensor image using semantic versioning
- Automatically use it for testing

This ensures tests always run against the latest available sensor version without manual updates.

**E2E Test Details:**

E2E tests are located in `tests/e2e/` and use Ginkgo BDD framework for:
- Better test organization with `Describe` and `It` blocks
- Focused test execution with `--focus` and `--skip` filters
- Parallel test execution support
- Clear, structured test output

Test coverage includes:
- Node sensor deployment verification
- DaemonSet scheduling validation
- Pod health checks
- Chart upgrade testing
- Resource cleanup verification
- Image auto-discovery from CrowdStrike registry

For more details, see the [E2E Test README](../tests/e2e/README.md).

#### Writing Tests

When adding new features or charts, ensure you add corresponding tests:

**Template Tests** ([tests/template/](../tests/template/)):
- Test Helm template rendering
- Verify values are applied correctly
- Check resource specifications
- Validate edge cases

**E2E Tests** ([tests/e2e/](../tests/e2e/)):
- Use Ginkgo BDD framework (`Describe`, `It`, `BeforeEach`)
- Test actual deployment to cluster
- Verify pod startup and health
- Test configuration changes
- Validate cleanup processes
- Use Gomega matchers for assertions

Follow existing patterns in each test directory. For e2e tests, use the Ginkgo BDD style with proper test descriptions.

### Updating the Chart.yaml

The `Chart.yaml` file requires a version bump for any changes that take place in any helm chart.
Both `version` and `appVersion` need to be changed.

* The `PATCH` version field should be changed whenever there is documentation or typo changes made.
* The `MINOR` version field should be changed whenever there are values add/changed, minor functionality changes in the templates, etc.
* The `MAJOR` version field should be changed whenever there is a new sensor or product enhancement.

## Releases

As part of modern cloud native architecture and development, Helm charts will automatically be updated and released when a pull request is merged.

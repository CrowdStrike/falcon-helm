.PHONY: help test-all test-sensor test-kac e2e-sensor e2e-install clean clean-e2e clean-e2e-resources

# Optional verbose flag (usage: make test-all V=1)
ifdef V
VERBOSE_FLAG = -v
GINKGO_VERBOSE = -v
else
VERBOSE_FLAG =
GINKGO_VERBOSE =
endif

# Default target
help:
	@echo "CrowdStrike Falcon Helm Charts - Available targets:"
	@echo ""
	@echo "Template Tests (fast, no cluster required):"
	@echo "  make test-all           - Run all template tests"
	@echo "  make test-sensor        - Run falcon-sensor template tests"
	@echo "  make test-kac           - Run falcon-kac template tests"
	@echo ""
	@echo "E2E Tests (requires Kubernetes cluster):"
	@echo "  make e2e-install        - Install Ginkgo CLI (required for e2e tests)"
	@echo "  make e2e-sensor         - Run falcon-sensor e2e tests"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean              - Clean test cache"
	@echo "  make clean-e2e          - Clean e2e test cache"
	@echo "  make clean-e2e-resources - Clean orphaned e2e test resources (namespaces, releases)"
	@echo "  make clean-e2e-resources-dry-run - Dry run: show what would be cleaned without deleting"
	@echo ""
	@echo "Options:"
	@echo "  V=1                     - Enable verbose output"
	@echo "  FALCON_CID=<cid>        - Set CID for e2e tests (required if API credentials not set)"
	@echo "  IMG=<image:tag>         - Sensor image to test (auto-discovered if not set with API credentials)"
	@echo "  E2E_REALTIME_OUTPUT=false - Disable real-time test output (buffered mode)"
	@echo "  FOCUS=<pattern>           - Run only tests matching pattern (e.g., FOCUS='Basic Deployment')"
	@echo "  SKIP=<pattern>            - Skip tests matching pattern (e.g., SKIP='Upgrade')"
	@echo ""
	@echo "Registry Authentication (optional):"
	@echo "  FALCON_CLIENT_ID=<id>       - Falcon API client ID (recommended for CrowdStrike registry)"
	@echo "  FALCON_CLIENT_SECRET=<sec>  - Falcon API client secret"
	@echo "  FALCON_CLOUD=<cloud>        - Falcon cloud region (us-1, us-2, eu-1, us-gov-1, us-gov-2, autodiscover) [default: autodiscover]"
	@echo "  REGISTRY_USERNAME=<user>    - Registry username (alternative method)"
	@echo "  REGISTRY_PASSWORD=<pass>    - Registry password (alternative method)"
	@echo "  REGISTRY_SERVER=<server>    - Registry server (auto-detected if not set)"
	@echo "  DOCKER_CONFIG_JSON=<json>   - Pre-encoded dockerconfigjson (alternative method)"
	@echo ""

# Run all tests
test-all:
	@echo "Running all chart tests..."
	@cd tests/template && go test $(VERBOSE_FLAG) ./...

# Run tests for falcon-sensor
test-sensor:
	@echo "Running falcon-sensor tests..."
	@cd tests/template && go test $(VERBOSE_FLAG) ./falcon-sensor

# Run tests for falcon-kac
test-kac:
	@echo "Running falcon-kac tests..."
	@cd tests/template && go test $(VERBOSE_FLAG) ./falcon-kac

# Clean test cache
clean:
	@echo "Cleaning test cache..."
	@cd tests/template && go clean -testcache

# Install Ginkgo CLI (required for e2e tests)
e2e-install:
	@echo "Installing Ginkgo CLI..."
	@go install github.com/onsi/ginkgo/v2/ginkgo@latest
	@echo "Ginkgo CLI installed successfully"
	@echo "Run 'make e2e-sensor' to execute falcon-sensor e2e tests"

# Run e2e tests for falcon-sensor
e2e-sensor:
	@echo "Running falcon-sensor e2e tests with Ginkgo..."
	@if [ -z "$(IMG)" ] && [ -z "$(FALCON_CLIENT_ID)" ]; then \
		echo "Error: Either IMG or FALCON_CLIENT_ID+FALCON_CLIENT_SECRET must be set"; \
		echo "Usage: make e2e-sensor IMG=<image:tag> FALCON_CID=<your-cid>"; \
		echo "   OR: make e2e-sensor FALCON_CLIENT_ID=<id> FALCON_CLIENT_SECRET=<secret> (IMG will be auto-discovered)"; \
		exit 1; \
	fi
	@if [ -z "$(FALCON_CID)" ] && [ -z "$(FALCON_CLIENT_ID)" ]; then \
		echo "Error: Either FALCON_CID or FALCON_CLIENT_ID+FALCON_CLIENT_SECRET must be set"; \
		echo "Usage: make e2e-sensor IMG=<image:tag> FALCON_CID=<your-cid>"; \
		echo "   OR: make e2e-sensor FALCON_CLIENT_ID=<id> FALCON_CLIENT_SECRET=<secret>"; \
		exit 1; \
	fi
	@if [ -n "$(FALCON_CLIENT_ID)" ] && [ -z "$(FALCON_CLIENT_SECRET)" ]; then \
		echo "Error: FALCON_CLIENT_SECRET must be set when FALCON_CLIENT_ID is provided"; \
		exit 1; \
	fi
	@if ! command -v ginkgo >/dev/null 2>&1; then \
		echo "Error: Ginkgo CLI not found. Please run 'make e2e-install' first"; \
		exit 1; \
	fi
	@cd tests/e2e/falcon-sensor && \
		$(if $(IMG),IMG=$(IMG),) \
		$(if $(FALCON_CID),FALCON_CID=$(FALCON_CID),) \
		FALCON_CLOUD=$(if $(FALCON_CLOUD),$(FALCON_CLOUD),autodiscover) \
		$(if $(FALCON_CLIENT_ID),FALCON_CLIENT_ID=$(FALCON_CLIENT_ID),) \
		$(if $(FALCON_CLIENT_SECRET),FALCON_CLIENT_SECRET=$(FALCON_CLIENT_SECRET),) \
		$(if $(REGISTRY_USERNAME),REGISTRY_USERNAME=$(REGISTRY_USERNAME),) \
		$(if $(REGISTRY_PASSWORD),REGISTRY_PASSWORD=$(REGISTRY_PASSWORD),) \
		$(if $(REGISTRY_SERVER),REGISTRY_SERVER=$(REGISTRY_SERVER),) \
		$(if $(DOCKER_CONFIG_JSON),DOCKER_CONFIG_JSON=$(DOCKER_CONFIG_JSON),) \
		$(if $(E2E_REALTIME_OUTPUT),E2E_REALTIME_OUTPUT=$(E2E_REALTIME_OUTPUT),) \
		ginkgo $(GINKGO_VERBOSE) \
		$(if $(FOCUS),--focus="$(FOCUS)",) \
		$(if $(SKIP),--skip="$(SKIP)",)

# Clean e2e test cache
clean-e2e:
	@echo "Cleaning e2e test cache..."
	@cd tests/e2e && go clean -testcache

# Clean orphaned e2e test resources (namespaces and Helm releases)
clean-e2e-resources:
	@echo "Cleaning orphaned e2e test resources..."
	@./tests/e2e/cleanup-test-resources.sh

# Clean orphaned e2e test resources (dry run)
clean-e2e-resources-dry-run:
	@echo "Dry run: checking for orphaned e2e test resources..."
	@DRY_RUN=true ./tests/e2e/cleanup-test-resources.sh

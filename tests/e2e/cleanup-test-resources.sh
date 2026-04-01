#!/bin/bash
#
# cleanup-test-resources.sh
# Cleanup orphaned e2e test resources (namespaces and Helm releases)
#
# This script finds and removes Kubernetes namespaces and Helm releases
# created by e2e tests that were not properly cleaned up due to test failures
# or interruptions.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE_PREFIX="falcon-test-"
AGE_THRESHOLD_MINUTES=${AGE_THRESHOLD_MINUTES:-60}
DRY_RUN=${DRY_RUN:-false}

echo "=================================================="
echo "E2E Test Resource Cleanup Script"
echo "=================================================="
echo ""
echo "Configuration:"
echo "  Namespace prefix: ${NAMESPACE_PREFIX}"
echo "  Age threshold: ${AGE_THRESHOLD_MINUTES} minutes"
echo "  Dry run: ${DRY_RUN}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: Cannot connect to Kubernetes cluster.${NC}"
    echo "Please ensure your kubeconfig is configured correctly."
    exit 1
fi

echo -e "${GREEN}✓ Connected to cluster${NC}"
echo ""

# Function to get namespace age in minutes
get_namespace_age_minutes() {
    local namespace=$1
    local creation_time=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)

    if [ -z "$creation_time" ]; then
        echo "0"
        return
    fi

    # Convert to epoch seconds (cross-platform)
    if date --version &>/dev/null 2>&1; then
        # GNU date (Linux)
        local creation_epoch=$(date -d "$creation_time" "+%s" 2>/dev/null || echo "0")
    else
        # BSD date (macOS)
        local creation_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$creation_time" "+%s" 2>/dev/null || echo "0")
    fi

    if [ "$creation_epoch" = "0" ]; then
        echo "0"
        return
    fi

    local current_epoch=$(date "+%s")
    local age_seconds=$((current_epoch - creation_epoch))
    local age_minutes=$((age_seconds / 60))

    echo "$age_minutes"
}

# Find all test namespaces
echo "Searching for test namespaces..."
NAMESPACES=$(kubectl get namespaces -o name | grep "namespace/${NAMESPACE_PREFIX}" | sed "s/namespace\///" || true)

if [ -z "$NAMESPACES" ]; then
    echo -e "${GREEN}No test namespaces found.${NC}"
    exit 0
fi

echo -e "${YELLOW}Found test namespaces:${NC}"
echo "$NAMESPACES" | while read -r ns; do
    age=$(get_namespace_age_minutes "$ns")
    echo "  - $ns (age: ${age}m)"
done
echo ""

# Count namespaces to delete
TOTAL_COUNT=$(echo "$NAMESPACES" | wc -l | tr -d ' ')
DELETE_COUNT=0
SKIP_COUNT=0

# Process each namespace
echo "Processing namespaces..."
echo ""

while read -r NAMESPACE; do
    [ -z "$NAMESPACE" ] && continue

    AGE=$(get_namespace_age_minutes "$NAMESPACE")

    # Handle negative ages (clock skew or future timestamps) - treat as very old
    if [ "$AGE" -lt 0 ]; then
        AGE=99999
    fi

    if [ "$AGE" -ge "$AGE_THRESHOLD_MINUTES" ] || [ "$AGE" -eq 0 ]; then
        DELETE_COUNT=$((DELETE_COUNT + 1))

        if [ "$DRY_RUN" = "true" ]; then
            echo -e "${YELLOW}[DRY RUN]${NC} Would delete namespace: $NAMESPACE (age: ${AGE}m)"

            # List Helm releases in the namespace
            RELEASES=$(helm list -n "$NAMESPACE" -q 2>/dev/null || true)
            if [ -n "$RELEASES" ]; then
                echo "  Helm releases to delete:"
                echo "$RELEASES" | while read -r release; do
                    echo "    - $release"
                done
            fi
        else
            echo -e "${RED}Deleting${NC} namespace: $NAMESPACE (age: ${AGE}m)"

            # Uninstall Helm releases first
            RELEASES=$(helm list -n "$NAMESPACE" -q 2>/dev/null || true)
            if [ -n "$RELEASES" ]; then
                echo "  Uninstalling Helm releases..."
                echo "$RELEASES" | while read -r release; do
                    echo "    - Uninstalling $release"
                    helm uninstall "$release" -n "$NAMESPACE" --wait --timeout 60s 2>/dev/null || echo "      Warning: Failed to uninstall $release"
                done
            fi

            # Delete the namespace
            kubectl delete namespace "$NAMESPACE" --timeout=60s 2>/dev/null || {
                echo "  Warning: Failed to delete namespace, attempting force delete..."
                kubectl delete namespace "$NAMESPACE" --grace-period=0 --force 2>/dev/null || echo "  Error: Could not delete namespace $NAMESPACE"
            }

            echo -e "${GREEN}✓ Deleted${NC}"
        fi
        echo ""
    else
        SKIP_COUNT=$((SKIP_COUNT + 1))
        echo -e "${GREEN}Skipping${NC} namespace: $NAMESPACE (age: ${AGE}m, threshold: ${AGE_THRESHOLD_MINUTES}m)"
    fi
done <<< "$NAMESPACES"

# Summary
echo "=================================================="
echo "Summary:"
echo "  Total namespaces found: $TOTAL_COUNT"
echo "  Namespaces deleted: $DELETE_COUNT"
echo "  Namespaces skipped: $SKIP_COUNT"

if [ "$DRY_RUN" = "true" ]; then
    echo ""
    echo -e "${YELLOW}This was a DRY RUN. No resources were deleted.${NC}"
    echo "To actually delete resources, run:"
    echo "  DRY_RUN=false $0"
fi
echo "=================================================="

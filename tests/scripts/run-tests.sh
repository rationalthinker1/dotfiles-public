#!/usr/bin/env bash
set -euo pipefail

# Main test runner for install.sh Docker-based testing
# Orchestrates building images and running all test scenarios

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# Track start time
START_TIME=$(date +%s)

# Change to project root
cd "$PROJECT_ROOT"

# Build base image first (for layer caching)
build_base() {
    log_step "Building base image..."
    if docker build -f tests/docker/Dockerfile.base -t dotfiles-test-base:latest . ; then
        log_info "Base image built successfully"
    else
        log_error "Failed to build base image"
        return 1
    fi
}

# Build all test scenario images
build_images() {
    log_step "Building test scenario images..."
    cd tests
    if docker compose build --parallel ; then
        cd ..
        log_info "All scenario images built successfully"
    else
        cd ..
        log_error "Failed to build scenario images"
        return 1
    fi
}

# Run tests in parallel
run_tests() {
    log_step "Running tests in parallel (this may take 3-5 minutes)..."
    log_info "Output from all containers will be shown below..."
    echo ""
    cd tests

    # Run all containers and wait for them to complete
    # Note: This will run all services in parallel
    # Output is shown live on the terminal
    docker compose up --abort-on-container-exit
    local result=$?

    cd ..
    return $result
}

# Collect and display results
collect_results() {
    log_step "Collecting test results..."

    local services=("ubuntu-desktop" "wsl-desktop")
    local all_passed=true
    local passed_count=0
    local failed_count=0

    echo ""
    echo "=========================================="
    echo "           TEST RESULTS SUMMARY"
    echo "=========================================="
    echo ""

    cd tests

    for service in "${services[@]}"; do
        echo "----------------------------------------"
        echo "Results for: $service"
        echo "----------------------------------------"

        # Get container exit code
        local exit_code=$(docker compose ps -q "$service" | xargs docker inspect -f '{{.State.ExitCode}}' 2>/dev/null || echo "255")

        if [[ "$exit_code" == "0" ]]; then
            log_info "✓ $service: PASSED"
            ((passed_count++))
        else
            log_error "✗ $service: FAILED (exit code: $exit_code)"
            ((failed_count++))
            all_passed=false

            # Show last 30 lines of logs for failed tests
            echo "Last 30 lines of output:"
            docker compose logs --tail=30 "$service" 2>/dev/null || echo "Could not retrieve logs"
        fi
        echo ""
    done

    cd ..

    echo "=========================================="
    if $all_passed; then
        log_info "All tests PASSED! ($passed_count/4 scenarios)"
        return 0
    else
        log_error "Some tests FAILED! ($passed_count passed, $failed_count failed)"
        return 1
    fi
}

# Cleanup containers and networks
cleanup() {
    log_step "Cleaning up containers and networks..."
    cd tests
    docker compose down -v 2>/dev/null || true
    cd ..
    log_info "Cleanup complete"
}

# Main execution flow
main() {
    log_info "Starting Docker-based install.sh tests..."
    echo ""

    # Ensure we cleanup on exit
    trap cleanup EXIT INT TERM

    # Step 1: Build base image
    if ! build_base; then
        log_error "Base image build failed. Aborting tests."
        exit 1
    fi
    echo ""

    # Step 2: Build scenario images
    if ! build_images; then
        log_error "Scenario image build failed. Aborting tests."
        exit 1
    fi
    echo ""

    # Step 3: Run tests
    local test_result=0
    if ! run_tests; then
        log_warn "Some tests may have failed. Checking results..."
        test_result=1
    fi
    echo ""

    # Step 4: Collect results
    if ! collect_results; then
        test_result=1
    fi

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    log_info "Total test duration: ${minutes}m ${seconds}s"
    echo ""

    if [[ $test_result -eq 0 ]]; then
        log_info "✓ All tests completed successfully!"
        exit 0
    else
        log_error "✗ Tests failed. Please review the output above."
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        cat <<EOF
Usage: $0 [OPTIONS]

Docker-based testing framework for install.sh

OPTIONS:
    --help, -h      Show this help message
    --no-cleanup    Don't cleanup containers after tests (for debugging)

DESCRIPTION:
    Runs comprehensive tests of install.sh across 4 scenarios:
    - ubuntu-server  (Linux, no desktop)
    - ubuntu-desktop (Linux with desktop packages)
    - wsl-server     (WSL simulation, no desktop)
    - wsl-desktop    (WSL simulation with desktop)

    Tests run in parallel using Docker Compose and validate:
    - Package installation (vim, rust, cargo packages, etc.)
    - Symlink creation (17 dotfile symlinks)
    - Log file success markers
    - Vim plugin installation
    - WSL-specific and desktop-specific features

EXAMPLES:
    # Run all tests
    $0

    # Run tests without cleanup (for debugging)
    $0 --no-cleanup

EOF
        exit 0
        ;;
    --no-cleanup)
        trap '' EXIT INT TERM
        ;;
esac

# Run main function
main "$@"

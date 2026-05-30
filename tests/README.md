# Docker-Based Testing Framework for install.sh

Comprehensive, automated testing framework for validating the dotfiles installation script across multiple environments without needing to create new servers.

## Overview

This testing framework uses Docker to validate `install.sh` across 2 key scenarios:

| Scenario | OS Type | Location | Description |
|----------|---------|----------|-------------|
| `ubuntu-desktop` | linux | desktop | Ubuntu 24.04 with desktop environment |
| `wsl-desktop` | wsl | desktop | WSL simulation with desktop packages |

**Note:** macOS testing is not included because Docker can only run Linux containers.

## Quick Start

### Prerequisites

- Docker installed and running
- Docker Compose installed
- ~5GB free disk space (for images)
- Internet connection (tests download packages)

### Run All Tests

```bash
cd ~/.dotfiles
./tests/scripts/run-tests.sh
```

That's it! The script will:
1. Build the base Docker image
2. Build all 4 test scenario images
3. Run all tests in parallel
4. Validate installation success
5. Report results
6. Cleanup containers

Expected runtime: **3-5 minutes** (first run may take longer)

## What Gets Tested

Each scenario validates:

### Core Installations
- ✅ Vim 9+ installed and functional
- ✅ Rust toolchain (rustc + cargo)
- ✅ Cargo packages (broot)
- ✅ System packages (zsh, git, tmux, htop, curl)

### Configuration
- ✅ All 17 dotfile symlinks created correctly
- ✅ Symlinks point to dotfiles directory
- ✅ Backup directory created

### Logs
- ✅ Install log exists
- ✅ No ERROR entries in log
- ✅ Installation completion marker present

### Plugins
- ✅ Vim plugins installed (>10 plugins)

### Scenario-Specific
- ✅ WSL scenarios: wslu package installed
- ✅ Desktop scenarios: fonts installation marker

## Expected Output

```
[INFO] Starting Docker-based install.sh tests...

[STEP] Building base image...
[INFO] Base image built successfully

[STEP] Building test scenario images...
[INFO] All scenario images built successfully

[STEP] Running tests in parallel (this may take 3-5 minutes)...

[STEP] Collecting test results...

==========================================
           TEST RESULTS SUMMARY
==========================================

----------------------------------------
Results for: ubuntu-desktop
----------------------------------------
[INFO] ✓ ubuntu-desktop: PASSED

----------------------------------------
Results for: wsl-desktop
----------------------------------------
[INFO] ✓ wsl-desktop: PASSED

==========================================
[INFO] All tests PASSED! (2/2 scenarios)

[INFO] Total test duration: 3m 45s

[INFO] ✓ All tests completed successfully!
```

## Directory Structure

```
tests/
├── docker/
│   ├── Dockerfile.base           # Shared base image (Ubuntu 22.04 + common deps)
│   ├── Dockerfile.ubuntu-server  # Standard Ubuntu
│   ├── Dockerfile.ubuntu-desktop # Ubuntu + desktop packages
│   ├── Dockerfile.wsl            # WSL simulation
│   └── Dockerfile.wsl-desktop    # WSL + desktop
├── scripts/
│   ├── run-tests.sh             # Main test runner
│   └── validate.sh              # Post-install validation checks
├── fixtures/
│   └── osrelease-wsl            # Mock kernel version for WSL detection
├── docker-compose.yml           # Orchestrates parallel test execution
└── README.md                    # This file
```

## Advanced Usage

### Run Without Cleanup (for Debugging)

```bash
./tests/scripts/run-tests.sh --no-cleanup
```

This leaves containers running so you can inspect them:

```bash
# List test containers
docker ps -a | grep dotfiles-test

# Inspect a specific container
docker exec -it dotfiles-test-ubuntu-server bash

# View logs
cd tests
docker-compose logs ubuntu-server

# Cleanup manually when done
docker-compose down -v
```

### Run Individual Scenarios

```bash
cd tests

# Run only ubuntu-server
docker-compose up ubuntu-server

# Run only WSL tests
docker-compose up wsl-server wsl-desktop
```

### View Help

```bash
./tests/scripts/run-tests.sh --help
```

## How It Works

### WSL Simulation

WSL is detected by checking `/proc/sys/kernel/osrelease` for the string "microsoft". We simulate this by:

1. Creating a fixture file with WSL kernel version
2. Bind mounting it into the container at `/proc/sys/kernel/osrelease`
3. Using `privileged: true` to allow /proc manipulation

### Desktop Detection

Desktop environments are detected by checking if the `ubuntu-desktop` package is installed. We trigger this by installing `ubuntu-desktop-minimal` in the desktop scenario Dockerfiles.

### Parallel Execution

All 4 scenarios run simultaneously using Docker Compose, reducing total test time from ~15-20 minutes (sequential) to ~3-5 minutes (parallel).

### Layer Caching

The base image pre-installs common dependencies (curl, git, sudo, etc.) so they're cached and don't need to be downloaded for each scenario.

## Troubleshooting

### Tests Fail with Network Errors

The tests require internet access to download packages. If you have network issues:

1. Check your internet connection
2. Try running tests again (install.sh has retry logic)
3. Check if you're behind a proxy that blocks Docker

### Out of Disk Space

Docker images can consume several GB. To clean up:

```bash
# Remove test images
docker rmi dotfiles-test-base dotfiles-test-ubuntu-server dotfiles-test-ubuntu-desktop dotfiles-test-wsl dotfiles-test-wsl-desktop

# Clean all unused Docker resources
docker system prune -a
```

### Tests Hang or Take Too Long

First run can take 10-15 minutes as it downloads all packages. Subsequent runs are faster (3-5 min) due to Docker layer caching.

If tests consistently hang:
- Check if a specific scenario is stuck: `docker ps`
- View logs: `cd tests && docker-compose logs --follow`
- Kill stuck containers: `docker-compose down`

### Permission Denied Errors

Ensure Docker is running and you have permissions:

```bash
# Test Docker access
docker ps

# If permission denied, add yourself to docker group
sudo usermod -aG docker $USER
# Then logout and login again
```

## Automating Tests

### Run on Every install.sh Change

Create a file watcher:

```bash
#!/usr/bin/env bash
# Save as tests/scripts/watch-and-test.sh

# Install inotify-tools if needed
command -v inotifywait || sudo apt-get install -y inotify-tools

echo "Watching install.sh for changes..."
while inotifywait -e modify install.sh; do
    echo "Change detected! Running tests..."
    ./tests/scripts/run-tests.sh
done
```

Make it executable and run:

```bash
chmod +x tests/scripts/watch-and-test.sh
./tests/scripts/watch-and-test.sh
```

### Git Pre-Push Hook

Automatically run tests before pushing:

```bash
# Create .git/hooks/pre-push
cat > .git/hooks/pre-push <<'EOF'
#!/usr/bin/env bash
echo "Running tests before push..."
./tests/scripts/run-tests.sh || {
    echo "Tests failed! Push aborted."
    echo "Use 'git push --no-verify' to skip tests."
    exit 1
}
EOF

chmod +x .git/hooks/pre-push
```

## Understanding Test Results

### All Tests Pass
Your install.sh is working correctly across all environments. Safe to deploy!

### Some Tests Fail
Check which scenario failed and review:
1. The last 30 lines of output (shown automatically)
2. Full logs: `cd tests && docker-compose logs <scenario-name>`
3. The install.log inside the container

### Specific Check Fails
The validation script shows exactly which check failed:
- `✗ FAIL: Vim version >= 9` - Vim installation or version issue
- `✗ FAIL: Symlink: .zshrc` - Symlink creation failed
- `✗ FAIL: No errors in log` - install.sh encountered errors

## Performance Notes

- **First run**: 10-15 minutes (downloads all packages, builds images)
- **Subsequent runs**: 3-5 minutes (uses Docker cache)
- **Just validation**: <1 minute (if images already built)

To speed up tests:
1. Don't delete images between runs
2. Run during good network times
3. Use an apt-caching proxy (optional, not included by default)

## Maintenance

### Update Base Image

If you need to update the Ubuntu version or base dependencies:

```bash
# Edit tests/docker/Dockerfile.base
vim tests/docker/Dockerfile.base

# Rebuild base image
docker build -f tests/docker/Dockerfile.base -t dotfiles-test-base:latest .

# Rebuild scenario images
cd tests
docker-compose build
```

### Add New Test Checks

Edit `tests/scripts/validate.sh` and add a new check function following the existing pattern:

```bash
check_new_feature() {
    if [[ condition ]]; then
        log_test "Feature name" "PASS"
    else
        log_test "Feature name" "FAIL" "details"
    fi
}

# Add to main()
check_new_feature
```

## FAQ

**Q: Do I need to create a new server to test changes?**
A: No! That's exactly what this framework eliminates. Just run `./tests/scripts/run-tests.sh`.

**Q: Can I test on macOS?**
A: Currently only Ubuntu and WSL are supported. macOS would require different Dockerfiles (and macOS Docker environment).

**Q: How accurate is this compared to a real server?**
A: Very accurate. The only differences are containerization-specific (no systemd, different /proc filesystem). All package installations, file operations, and configurations are identical.

**Q: Can I run this in CI/CD?**
A: Yes! The test runner is designed for automated environments. Just ensure Docker is available in your CI environment.

**Q: What if I only want to test one scenario?**
A: Use docker-compose directly: `cd tests && docker-compose up <scenario-name>`

## Contributing

To improve this testing framework:

1. Test your changes to the framework
2. Ensure all 4 scenarios still pass
3. Update this README if you add new features
4. Keep test execution time under 5 minutes when possible

## License

Same as the parent dotfiles repository.

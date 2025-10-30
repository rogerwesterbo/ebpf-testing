# Development Guide

This guide covers development workflows for the eBPF TCP Connection Monitor.

## Development Environment Setup

### Prerequisites

- Go 1.25+
- Clang and LLVM (for eBPF compilation)
- Linux kernel headers for your architecture
- Docker with buildx support (optional, for container builds)
- Make

### Quick Setup

```bash
# Install development dependencies
make dev-setup

# Build everything
make build-all

# Run tests
make test

# Check code quality
make lint
make go-security-scan
```

## Architecture Support

### Current Support Matrix

| Architecture  | Status          | Docker Platform | Makefile Target     |
| ------------- | --------------- | --------------- | ------------------- |
| AMD64/x86_64  | ✅ Full         | `linux/amd64`   | `TARGET_ARCH=x86`   |
| ARM64/AArch64 | ✅ Full         | `linux/arm64`   | `TARGET_ARCH=arm64` |
| ARM32         | ✅ Full         | `linux/arm/v7`  | `TARGET_ARCH=arm`   |
| RISC-V 64     | ✅ Experimental | `linux/riscv64` | `TARGET_ARCH=riscv` |

### Building for Different Architectures

#### eBPF Programs

```bash
# Current architecture (auto-detected)
make build-ebpf

# Specific architecture
make build-ebpf-arch TARGET_ARCH=arm64
make build-ebpf-arch TARGET_ARCH=arm
make build-ebpf-arch TARGET_ARCH=riscv

# All architectures
make build-cross
```

#### Go Applications

```bash
# Current platform
make build-agent

# Cross-compile for specific architecture
make build-agent-arch GOARCH=arm64
make build-agent-arch GOARCH=arm GOARM=7

# Environment variables for fine control
GOOS=linux GOARCH=arm64 make build-agent-arch
GOOS=linux GOARCH=arm GOARM=7 make build-agent-arch
```

#### Docker Images

```bash
# Single architecture
make docker-build-arch DOCKER_PLATFORM=linux/arm64

# Multi-architecture (requires buildx)
make docker-build-multi

# Push multi-architecture to registry
REGISTRY=ghcr.io/username make docker-push-multi
```

## Development Workflow

### 1. Making Changes

```bash
# Create feature branch
git checkout -b feature/your-feature

# Make changes to code
# ...

# Test changes
make test
make lint
```

### 2. Testing eBPF Changes

```bash
# Build eBPF program
make build-ebpf

# Test locally (requires root)
sudo ./bin/agent

# Check metrics
curl http://localhost:9090/metrics
```

### 3. Testing Multi-Architecture

```bash
# Build for all architectures
make build-cross

# Test Docker builds
make docker-build-multi
```

### 4. Submitting Changes

```bash
# Ensure everything passes
make test lint go-security-scan

# Commit and push
git add .
git commit -m "feat: your feature description"
git push origin feature/your-feature
```

## Common Development Tasks

### Adding Support for New Architecture

1. **Update eBPF Makefile** (`eBPF/Makefile`):

   ```makefile
   # Add architecture case in help and validation
   ```

2. **Update main Dockerfile**:

   ```dockerfile
   # Add case for new architecture in both package installation and build steps
   "newarch") apt-get install -y linux-headers-newarch || true ;;
   "newarch") make TARGET_ARCH=newarch ;;
   ```

3. **Update CI/CD** (`.github/workflows/ci.yml`):

   ```yaml
   # Add new matrix entry
   - arch: newarch
     target_arch: newarch
     platform: linux/newarch
   ```

4. **Test the new architecture**:
   ```bash
   make build-ebpf-arch TARGET_ARCH=newarch
   docker build --platform linux/newarch .
   ```

### Debugging eBPF Issues

```bash
# Verify eBPF program structure
llvm-objdump -S eBPF/tcpconnect.bpf.o

# Check BPF verifier output
sudo dmesg | grep bpf

# List loaded BPF programs
sudo bpftool prog list

# Inspect maps
sudo bpftool map list
sudo bpftool map dump id <map_id>
```

### Performance Testing

```bash
# Run benchmarks
make bench

# Profile specific benchmarks
make bench-profile BENCH=BenchmarkSpecific

# Memory profiling
go tool pprof bench.mem

# CPU profiling
go tool pprof bench.cpu
```

## Project Structure

```
.
├── .github/workflows/     # CI/CD pipelines
├── charts/               # Kubernetes Helm charts
├── cmd/agent/           # Main application entry point
├── configs/             # Configuration files
├── docs/                # Documentation
│   └── DEVELOPMENT.md   # This development guide
├── eBPF/                # eBPF programs and build system
│   ├── Makefile        # Architecture-aware eBPF builds
│   └── *.bpf.c         # eBPF kernel programs
├── bin/                 # Build outputs (gitignored)
├── Dockerfile           # Multi-architecture container build
├── Makefile            # Main build system
├── docker-compose.yml   # Local development environment
└── README.md           # User documentation
```

## Build System Details

### Makefile Targets

| Target        | Description                                   |
| ------------- | --------------------------------------------- |
| `help`        | Show all available targets                    |
| `build-all`   | Build both eBPF and Go components             |
| `build-cross` | Cross-compile for all supported architectures |
| `test`        | Run unit tests with coverage                  |
| `lint`        | Run code quality checks                       |
| `clean`       | Remove all build artifacts                    |
| `arch-info`   | Display architecture support information      |

### Architecture Detection

The build system uses several mechanisms for architecture detection:

1. **Go**: Uses `GOOS`/`GOARCH` environment variables
2. **eBPF**: Uses `TARGET_ARCH` Makefile variable
3. **Docker**: Uses `TARGETARCH`/`TARGETPLATFORM` build args
4. **CI/CD**: Uses matrix strategy for parallel builds

## Debugging

This section covers debugging the eBPF TCP Monitor in various environments.

### Quick Start - Debug in Kubernetes

The fastest way to debug in your Kubernetes cluster:

```bash
# 1. Start debug environment (builds, deploys, port-forwards)
./scripts/debug-k8s.sh
```

Keep this terminal open - it's forwarding the debugger port!

```
# 2. In VS Code: Press F5 → Select "Attach to Kubernetes Pod"
# 3. Set breakpoints and debug!
```

**Useful breakpoint locations:**

- `pkg/ebpf/manager.go:40` - eBPF program loading
- `pkg/metrics/collector.go:85` - Metrics collection
- `pkg/health/health.go:60` - Health checks

**Keyboard shortcuts:**

- **F5**: Continue, **F9**: Toggle breakpoint, **F10**: Step over
- **F11**: Step into, **Shift+F11**: Step out, **Shift+F5**: Stop

**Cleanup:** `Ctrl+C` on debug script, then `./scripts/cleanup-debug.sh`

### Debugging Options

#### Option 1: Remote Debugging in Kubernetes (Recommended)

Debug the application running in your actual Kubernetes cluster.

**Prerequisites:**

- VS Code with Go extension
- `kubectl` access to cluster
- Docker Desktop

**Manual steps** (or use `./scripts/debug-k8s.sh`):

```bash
# Build debug image
docker build -f Dockerfile.debug -t ebpf-testing:debug .

# Deploy to Kubernetes
kubectl apply -f k8s/debug-deployment.yaml

# Verify pod is running
kubectl get pods -n ebpf-debug

# Setup port forwarding
POD_NAME=$(kubectl get pods -n ebpf-debug -l app=ebpf-testing-debug -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n ebpf-debug $POD_NAME 2345:2345
```

Then in VS Code: F5 → "Attach to Kubernetes Pod"

#### Option 2: Local Debugging

⚠️ **Note**: eBPF won't work on macOS, but useful for debugging Go logic.

```bash
# Build eBPF (in Docker or Linux)
make build-ebpf

# In VS Code: Select "Debug Local (requires root)" and press F5
```

#### Option 3: Debug in Docker Container

```bash
# Run with debug port exposed
docker run --rm --privileged --pid=host \
  -p 2345:2345 -p 9090:9090 -p 8080:8080 \
  ebpf-testing:debug

# In VS Code: F5 → "Attach to Kubernetes Pod"
```

### Debug Workflow Tips

**Inspecting Variables:**

- **Variables Panel**: Auto-shows local variables
- **Watch Panel**: Add custom expressions
- **Call Stack**: See execution path
- **Debug Console**: Execute Go code at breakpoint

**Common debug scenarios:**

1. **eBPF loading issues** - Breakpoint in `pkg/ebpf/manager.go`:

   ```go
   func NewManager(cfg Config) (*Manager, error) {
       spec, err := ebpf.LoadCollectionSpec(cfg.ObjectPath)
       if err != nil {
           return nil, fmt.Errorf("load spec: %w", err) // <-- Set breakpoint
       }
   ```

2. **Metrics collection** - Breakpoint in `pkg/metrics/collector.go`:

   ```go
   func (c *Collector) collect() {
       iter := c.countsMap.Iterate()
       for iter.Next(&pid, &val) { // <-- Set breakpoint
           counts = append(counts, pidCount{pid, val})
       }
   ```

3. **Health checks** - Breakpoint in `pkg/health/health.go`:
   ```go
   func (c *Checker) ReadinessHandler(w http.ResponseWriter, r *http.Request) {
       if c.IsReady() { // <-- Set breakpoint
           w.WriteHeader(http.StatusOK)
   ```

### Debug Troubleshooting

**Port forward fails:**

```bash
# Check pod status
kubectl get pods -n ebpf-debug
kubectl logs -n ebpf-debug -l app=ebpf-testing-debug

# Verify Delve is listening
kubectl exec -n ebpf-debug $POD_NAME -- netstat -tlnp | grep 2345
```

**Debugger won't attach:**

```bash
# Check port forwarding is active
lsof -i :2345

# Check VS Code output: View → Output → Select "Go"
```

**eBPF won't load in pod:**

```bash
# Verify pod privileges
kubectl get pod -n ebpf-debug $POD_NAME -o jsonpath='{.spec.containers[0].securityContext}'

# Should show: privileged:true and capabilities including SYS_ADMIN, BPF

# Check kernel support
kubectl exec -n ebpf-debug $POD_NAME -- cat /proc/sys/kernel/bpf_disabled
# Should be 0
```

**Performance issues while debugging:**

```bash
# Increase probe timeouts in k8s/debug-deployment.yaml
# Or temporarily disable probes:
kubectl patch deployment -n ebpf-debug ebpf-testing-debug \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"agent","startupProbe":null}]}}}}'
```

### Advanced Debugging

**Debug specific node:**

```bash
# Patch DaemonSet to run on specific node
kubectl patch daemonset -n ebpf-debug ebpf-testing-debug \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"node-name"}}}}}'
```

**View eBPF maps:**

```bash
kubectl exec -n ebpf-debug -it $POD_NAME -- bpftool prog list
kubectl exec -n ebpf-debug -it $POD_NAME -- bpftool map list
```

**Network traffic capture:**

```bash
kubectl exec -n ebpf-debug $POD_NAME -- tcpdump -i any -w /tmp/capture.pcap
kubectl cp ebpf-debug/$POD_NAME:/tmp/capture.pcap ./capture.pcap
```

## Troubleshooting

### Common Issues

1. **eBPF Compilation Fails**

   ```bash
   # Check clang version
   clang --version

   # Verify kernel headers
   ls /usr/include/linux/
   ```

2. **Cross-compilation Issues**

   ```bash
   # Clean and rebuild
   make clean
   make build-cross
   ```

3. **Docker Build Fails**

   ```bash
   # Check buildx setup
   docker buildx ls

   # Create new builder if needed
   docker buildx create --use
   ```

### Getting Help

- Check the main [README.md](../README.md) for usage information
- Review [GitHub Issues](https://github.com/rogerwesterbo/ebpf-testing/issues)
- Run `make help` for available build targets
- Run `make arch-info` for architecture support details

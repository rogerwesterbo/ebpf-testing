# eBPF TCP Connection Monitor

A multi-architecture eBPF application that monitors TCP connections and exports metrics to Prometheus. This tool uses a kernel probe (kprobe) to track `tcp_connect()` calls and counts them per process ID (PID).

## Features

- **eBPF-based monitoring**: Minimal overhead kernel-space monitoring
- **Multi-architecture support**: Builds for AMD64, ARM64, ARM, and RISC-V
- **Prometheus integration**: Exports metrics on `:9090/metrics`
- **Container-ready**: Optimized Docker builds for multiple platforms
- **Kubernetes deployment**: Helm charts included

## Architecture Support

This project supports building and running on multiple architectures:

| Architecture  | Docker Platform | Makefile Target     | Status       |
| ------------- | --------------- | ------------------- | ------------ |
| AMD64/x86_64  | `linux/amd64`   | `TARGET_ARCH=x86`   | ✅ Supported |
| ARM64/AArch64 | `linux/arm64`   | `TARGET_ARCH=arm64` | ✅ Supported |
| ARM32         | `linux/arm/v7`  | `TARGET_ARCH=arm`   | ✅ Supported |
| RISC-V 64     | `linux/riscv64` | `TARGET_ARCH=riscv` | ✅ Supported |

## Quick Start

### Prerequisites

- **For Docker builds**: Docker with buildx support
- **For local builds**: Go 1.25+, Clang, LLVM, and Linux kernel headers (or use Docker on macOS)
- **For Kubernetes**: kubectl access to a cluster with eBPF support
- **For debugging**: VS Code with Go extension

### Using Docker (Recommended)

```bash
# Build for your current platform
docker build -t ebpf-tcp-monitor .

# Run the container (requires privileged mode for eBPF)
docker run --rm --privileged --pid=host \
  -p 9090:9090 \
  ebpf-tcp-monitor
```

### Quick Debug in Kubernetes (3 Steps)

Want to debug with breakpoints in VS Code? It's easy:

```bash
# 1. Start the debug environment (one command)
./scripts/debug-k8s.sh
```

This builds, deploys, and starts port-forwarding. Keep this terminal open!

```
# 2. In VS Code: Press F5 → Select "Attach to Kubernetes Pod"
```

```
# 3. Set breakpoints and debug!
# Try: pkg/ebpf/manager.go:40 or pkg/metrics/collector.go:85
```

**Debug Controls**: F5 (continue), F10 (step over), F11 (step into), Shift+F5 (stop)

When done: `Ctrl+C` on the debug script, then run `./scripts/cleanup-debug.sh`

> 📚 For detailed debugging guide, see [docs/DEVELOPMENT.md#debugging](docs/DEVELOPMENT.md#debugging)

### Multi-Platform Docker Builds

```bash
# Setup buildx (one-time setup)
docker buildx create --use

# Build for multiple architectures
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t your-registry/ebpf-tcp-monitor:latest \
  --push .

# Build for specific architecture
docker build --platform linux/arm64 -t ebpf-tcp-monitor:arm64 .
```

### Local Development

#### Building the eBPF Program

```bash
cd eBPF/

# Build for current architecture (x86 default)
make

# Build for ARM64
make TARGET_ARCH=arm64

# Build for ARM32
make TARGET_ARCH=arm

# Build for RISC-V
make TARGET_ARCH=riscv

# See all options
make help
```

#### Building the Go Application

```bash
# Build for current platform
go build -o agent ./cmd/agent

# Cross-compile for ARM64
GOOS=linux GOARCH=arm64 go build -o agent-arm64 ./cmd/agent
```

## Usage

### Running Locally

```bash
# Ensure you have the eBPF object file
cd eBPF && make && cd ..

# Run the agent (requires root privileges)
sudo ./agent
```

### Accessing Metrics and Health Checks

Once running, the application exposes multiple endpoints:

**Metrics (Port 9090):**

```
http://localhost:9090/metrics
```

**Health Checks (Port 8080):**

```
http://localhost:8080/readiness  # Kubernetes readiness probe
http://localhost:8080/liveness   # Kubernetes liveness probe
http://localhost:8080/health     # Detailed health information (JSON)
```

**Example outputs:**

_Metrics endpoint:_

```
# HELP tcp_connects_by_pid Number of tcp_connect() calls observed per PID
# TYPE tcp_connects_by_pid gauge
tcp_connects_by_pid{comm="curl",pid="1234"} 5
tcp_connects_by_pid{comm="firefox",pid="5678"} 12
```

_Health endpoint:_

```json
{ "ready": true, "alive": true, "timestamp": 1730316000 }
```

### Kubernetes Deployment

```bash
# Install using Helm
helm install ebpf-tcp-monitor ./charts/ebpf-testing

# Or apply directly
kubectl apply -f charts/ebpf-testing/templates/
```

## How It Works

1. **eBPF Program** (`tcpconnect.bpf.c`):

   - Attaches a kprobe to the kernel's `tcp_connect()` function
   - Counts connection attempts per PID in a BPF hash map
   - Runs in kernel space with minimal overhead

2. **User-space Agent** (`cmd/agent/main.go`):

   - Loads the compiled eBPF program into the kernel
   - Polls the BPF map every 5 seconds
   - Resolves PIDs to process names via `/proc/<pid>/comm`
   - Exports data as Prometheus metrics on port 9090
   - Provides Kubernetes health checks on port 8080

3. **Multi-Architecture Build**:
   - Dockerfile uses Docker's automatic platform detection
   - Makefile supports parameterized architecture builds
   - Proper kernel headers installed for each platform

## Documentation

📚 **Detailed documentation is available in the [`docs/`](docs/) folder:**

- **[Development Guide](docs/DEVELOPMENT.md)** - Complete developer documentation:

  - Development environment setup
  - Building for different architectures
  - Debugging with VS Code (remote debugging in Kubernetes)
  - Testing and code quality checks
  - Adding new features and architecture support
  - Troubleshooting common issues

- **[Architecture Overview](docs/ARCHITECTURE.md)** - Code organization and design:

  - Package structure and responsibilities
  - Health check implementation
  - Design principles and patterns
  - Testing strategy

- **[Release Process](docs/RELEASING.md)** - How to create new releases:
  - Creating releases with semantic versioning
  - Automated release workflow
  - Docker image and Helm chart publishing
  - Troubleshooting releases

## Project Structure

```
.
├── README.md                    # This file - overview, quick start, and usage
├── docs/                        # 📚 Detailed documentation (2 files)
│   ├── ARCHITECTURE.md         # Code structure, design patterns, health checks
│   └── DEVELOPMENT.md          # Development guide, building, debugging
├── Dockerfile                   # Multi-arch container build
├── Dockerfile.debug            # Debug build with Delve debugger
├── Makefile                     # Top-level build targets
├── docker-compose.yml          # Local development environment
├── go.mod                       # Go module definition
├── .vscode/                     # VS Code configuration
│   ├── launch.json             # Debug configurations
│   └── tasks.json              # Build tasks
├── configs/                     # Configuration files
│   └── prometheus.yml          # Prometheus monitoring config
├── scripts/                     # Helper scripts
│   ├── debug-k8s.sh           # Quick debug setup for Kubernetes
│   └── cleanup-debug.sh        # Cleanup debug resources
├── k8s/                         # Kubernetes manifests
│   └── debug-deployment.yaml   # Debug DaemonSet for remote debugging
├── cmd/agent/                   # Application entry point
│   └── main.go                 # Main application
├── pkg/                         # Public packages (reusable)
│   ├── ebpf/                   # eBPF program management
│   ├── health/                 # Health check handlers
│   ├── metrics/                # Metrics collection
│   └── server/                 # HTTP server management
├── internal/                    # Private packages (internal use only)
│   └── procfs/                 # Process information utilities
├── eBPF/
│   ├── Makefile                # eBPF build system with arch support
│   └── tcpconnect.bpf.c        # eBPF kernel probe program
├── charts/ebpf-testing/        # Kubernetes Helm chart
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/              # K8s resource templates
└── .github/workflows/          # CI/CD pipelines
    └── ci.yml                  # Multi-architecture build and test
```

For detailed information about the code organization, see the **[Architecture Documentation](docs/ARCHITECTURE.md)**.

## Development

For detailed development information, see the **[Development Guide](docs/DEVELOPMENT.md)**.

### Quick Development Setup

```bash
# Setup development environment
make dev-setup

# Build everything
make build-all

# Run tests and checks
make test lint

# Show architecture support info
make arch-info
```

### Adding New Architectures

For complete instructions on adding support for new architectures, see the [Development Guide](docs/DEVELOPMENT.md#adding-support-for-new-architecture).

Quick overview:

1. Update `eBPF/Makefile` with new architecture mapping
2. Update `Dockerfile` with architecture-specific build steps
3. Test the build: `docker build --platform linux/new_arch .`

## Troubleshooting

For detailed troubleshooting information, see the **[Development Guide](docs/DEVELOPMENT.md#troubleshooting)**.

### Common Issues

1. **Permission Denied**: eBPF requires root privileges or CAP_BPF capability
2. **Program Load Failed**: Ensure kernel supports eBPF and has necessary features
3. **Architecture Mismatch**: Verify the eBPF program was built for the correct architecture

### Quick Debug Commands

```bash
# Check eBPF program info
sudo bpftool prog list

# Verify loaded maps
sudo bpftool map list

# Check kernel eBPF support
zgrep CONFIG_BPF /proc/config.gz
```

For more debugging techniques and solutions, see the [Development Guide](docs/DEVELOPMENT.md#troubleshooting).

## License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test on multiple architectures if possible
4. Submit a pull request

---

**Note**: This tool requires privileged access to load eBPF programs into the kernel. Always review eBPF code before running in production environments.

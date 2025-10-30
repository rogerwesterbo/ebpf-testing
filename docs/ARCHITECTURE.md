# Package Structure

This document describes the package organization of the eBPF TCP Connection Monitor.

## Overview

The codebase is organized into well-defined packages with clear responsibilities:

```
.
├── cmd/agent/              # Application entry point
├── pkg/                    # Public packages (can be imported by external projects)
│   ├── ebpf/              # eBPF program management
│   ├── health/            # Health check handlers
│   ├── metrics/           # Metrics collection and export
│   └── server/            # HTTP server management
└── internal/              # Private packages (internal use only)
    └── procfs/            # Process information utilities
```

## Package Details

### `cmd/agent`

**Purpose**: Main application entry point

**Responsibilities**:

- Initialize all components
- Wire dependencies together
- Handle graceful shutdown
- Coordinate application lifecycle

**Key Files**:

- `main.go` - Application bootstrapping and coordination

---

### `pkg/ebpf`

**Purpose**: eBPF program loading and management

**Responsibilities**:

- Load eBPF object files
- Attach kprobes to kernel symbols
- Manage eBPF maps
- Clean up resources on shutdown

**Key Types**:

- `Manager` - Main eBPF lifecycle manager
- `Config` - Configuration for eBPF loading

**Example Usage**:

```go
mgr, err := ebpf.NewManager(ebpf.DefaultConfig())
if err != nil {
    log.Fatal(err)
}
defer mgr.Close()

countsMap := mgr.GetCountsMap()
```

---

### `pkg/health`

**Purpose**: Kubernetes health check implementation

**Responsibilities**:

- Track application readiness state
- Track application liveness state
- Provide HTTP handlers for probes
- Export health status in JSON format

**Key Types**:

- `Checker` - Health state manager
- `Status` - Health status representation

**Example Usage**:

```go
healthChecker := health.NewChecker()
healthChecker.SetReady(true)

http.HandleFunc("/readiness", healthChecker.ReadinessHandler)
http.HandleFunc("/liveness", healthChecker.LivenessHandler)
```

**Endpoints**:

- `/readiness` - Returns 200 if ready, 503 otherwise
- `/liveness` - Returns 200 if alive, 503 otherwise
- `/health` - Returns detailed JSON status

---

### `pkg/metrics`

**Purpose**: Collect eBPF data and export as Prometheus metrics

**Responsibilities**:

- Poll eBPF maps periodically
- Resolve PIDs to process names
- Update Prometheus gauges
- Handle collection errors gracefully

**Key Types**:

- `Collector` - Metrics collection manager
- `Config` - Collector configuration

**Example Usage**:

```go
collector := metrics.NewCollector(metrics.Config{
    CountsMap: ebpfMap,
    Interval:  5 * time.Second,
    OnError: func(err error) {
        log.Printf("Error: %v", err)
    },
})
collector.Start()
defer collector.Stop()
```

---

### `pkg/server`

**Purpose**: HTTP server management

**Responsibilities**:

- Manage metrics server (port 9090)
- Manage health check server (port 8080)
- Coordinate graceful shutdown
- Handle server lifecycle

**Key Types**:

- `Manager` - Server lifecycle manager
- `Config` - Server configuration

**Example Usage**:

```go
serverMgr := server.NewManager(server.Config{
    MetricsAddr: ":9090",
    HealthAddr:  ":8080",
    HealthCheck: healthChecker,
})

serverMgr.Start()
defer serverMgr.ShutdownGracefully(10 * time.Second)
```

**Port Separation**: The application exposes two distinct HTTP servers:

- **Port 9090**: Metrics endpoint (`/metrics`)
- **Port 8080**: Health check endpoints

This separation follows the principle of least privilege and allows for different security policies.

---

### `internal/procfs`

**Purpose**: Process information utilities

**Responsibilities**:

- Read process information from `/proc`
- Resolve PIDs to process names
- Handle missing processes gracefully

**Key Functions**:

- `GetProcessName(pid int) string` - Get process name for a PID

**Example Usage**:

```go
import "github.com/rogerwesterbo/ebpf-testing/internal/procfs"

processName := procfs.GetProcessName(1234)
```

**Note**: This is an internal package and should not be imported by external projects.

## Design Principles

### Separation of Concerns

Each package has a single, well-defined responsibility. This makes the code easier to:

- Understand
- Test
- Maintain
- Extend

### Dependency Injection

Components receive their dependencies through configuration structs, making them:

- Testable in isolation
- Reusable in different contexts
- Easy to mock for testing

### Error Handling

Errors are propagated up to the caller, allowing for centralized error handling and recovery strategies.

### Resource Management

Each manager type owns its resources and provides:

- Initialization methods
- Cleanup/Close methods
- Defer-friendly interfaces

## Testing Strategy

Each package can be tested independently:

```go
// Example test for health package
func TestHealthChecker(t *testing.T) {
    checker := health.NewChecker()

    if checker.IsReady() {
        t.Error("Should not be ready initially")
    }

    checker.SetReady(true)

    if !checker.IsReady() {
        t.Error("Should be ready after SetReady(true)")
    }
}
```

## Adding New Features

When adding new functionality:

1. **Determine the right package**: Does it fit in an existing package or need a new one?
2. **Follow existing patterns**: Use similar structure to existing packages
3. **Keep it focused**: Each package should have a single responsibility
4. **Document public APIs**: Add godoc comments for exported types and functions
5. **Add tests**: Test packages in isolation

## Health Check Implementation

### Overview

The application implements Kubernetes-style health checks with dedicated endpoints for liveness, readiness, and detailed health status.

### Health Check Endpoints

#### Liveness Probe - `:8080/liveness`

**Purpose**: Determines if the application is running and not deadlocked.

**Behavior**:

- Returns HTTP 200 when the application is alive
- Returns HTTP 503 if the application has encountered a fatal error
- Kubernetes will restart the pod if this check fails repeatedly

**Implementation**:

- Set to `alive` immediately on application start
- Set to `not alive` if critical goroutines panic or fatal errors occur

#### Readiness Probe - `:8080/readiness`

**Purpose**: Determines if the application is ready to receive traffic.

**Behavior**:

- Returns HTTP 200 when the eBPF program is loaded and attached successfully
- Returns HTTP 503 during startup or shutdown phases
- Kubernetes will remove the pod from service load balancing if this check fails

**Implementation**:

- Set to `ready` only after eBPF program loads and attaches successfully
- Set to `not ready` during graceful shutdown

#### Detailed Health - `:8080/health`

**Purpose**: Provides detailed health information in JSON format.

**Response Format**:

```json
{
  "ready": true,
  "alive": true,
  "timestamp": 1730316000
}
```

### Kubernetes Configuration

**Probe Configuration** (in Helm values):

```yaml
livenessProbe:
  httpGet:
    path: /liveness
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /readiness
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3

startupProbe:
  httpGet:
    path: /readiness
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 2
  timeoutSeconds: 3
  failureThreshold: 30 # Allow up to 60 seconds for startup
```

### Testing Health Checks

**Local Testing:**

```bash
# Start the application (requires root for eBPF)
sudo ./bin/agent

# Test endpoints (in another terminal)
curl http://localhost:8080/liveness   # Should return "OK"
curl http://localhost:8080/readiness  # Should return "Ready"
curl http://localhost:8080/health     # Should return JSON
```

**Kubernetes Testing:**

```bash
# Deploy the application
helm install ebpf-monitor ./charts/ebpf-testing

# Check pod status
kubectl get pods -l app.kubernetes.io/name=ebpf-testing

# Test via port-forward
kubectl port-forward deployment/ebpf-testing 8080:8080
curl http://localhost:8080/health
```

### Implementation Details

**Thread Safety**: Health state is managed using atomic operations (`sync/atomic`) to ensure thread-safe reads and writes across goroutines.

**Error Handling**:

- **Metrics collection errors**: Mark as not alive to trigger restart
- **eBPF loading errors**: Fatal exit during startup (never becomes ready)
- **HTTP server errors**: Logged but don't affect health state for non-critical servers

**Graceful Shutdown**:

1. Mark as not ready (stops receiving new traffic)
2. Continue serving existing requests with timeout
3. Clean up eBPF resources
4. Shutdown both HTTP servers gracefully

**Security Considerations**:

- Health check server runs on separate port (8080) from metrics (9090)
- No sensitive information exposed in health responses
- Simple text responses for probes, JSON for detailed info
- Can be configured with different security policies per port

## Package Dependencies

```
cmd/agent
  ├─> pkg/ebpf
  ├─> pkg/health
  ├─> pkg/metrics
  │     └─> internal/procfs
  └─> pkg/server
        └─> pkg/health
```

**Guidelines**:

- `cmd/` can import from `pkg/` and `internal/`
- `pkg/` packages can import other `pkg/` packages (avoid circular dependencies)
- `pkg/` packages can import from `internal/`
- `internal/` packages should not import from `pkg/` or `cmd/`
- External projects can only import from `pkg/` (not `internal/` or `cmd/`)

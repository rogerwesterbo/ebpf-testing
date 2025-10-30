# Build BPF + Go in a builder stage
FROM golang:1.25-bookworm AS build

# Use Docker's automatic platform detection
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETOS

# Install architecture-specific packages including bpftool and libbpf
RUN apt-get update && apt-get install -y clang llvm make bpftool libbpf-dev \
    && case "${TARGETARCH}" in \
        "amd64") apt-get install -y linux-headers-amd64 || true ;; \
        "arm64") apt-get install -y linux-headers-arm64 || true ;; \
        "arm") apt-get install -y linux-headers-armmp || true ;; \
        *) echo "Installing generic linux headers" && apt-get install -y linux-headers-generic || true ;; \
    esac

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY eBPF/ eBPF/

# Build BPF with architecture-specific target
WORKDIR /src/eBPF
# Generate vmlinux.h from the build container's kernel
RUN bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h || \
    echo "Warning: Could not generate vmlinux.h from BTF, using fallback"
RUN case "${TARGETARCH}" in \
        "amd64") make TARGET_ARCH=x86 ;; \
        "arm64") make TARGET_ARCH=arm64 ;; \
        "arm") make TARGET_ARCH=arm ;; \
        "riscv64") make TARGET_ARCH=riscv ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac

# Build Go application for target architecture
WORKDIR /src
COPY cmd/ cmd/
COPY pkg/ pkg/
COPY internal/ internal/
RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o /out/agent ./cmd/agent

# Minimal runtime
FROM gcr.io/distroless/base-debian13
WORKDIR /
COPY --from=build /out/agent /agent
COPY --from=build /src/eBPF/tcpconnect.bpf.o /bpf/tcpconnect.bpf.o
USER 0
ENTRYPOINT ["/agent"]

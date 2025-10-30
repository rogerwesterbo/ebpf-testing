# Makefile for the project
# inspired by kubebuilder.io

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

# Basic colors
BLACK=\033[0;30m
RED=\033[0;31m
GREEN=\033[0;32m
YELLOW=\033[0;33m
BLUE=\033[0;34m
PURPLE=\033[0;35m
CYAN=\033[0;36m
WHITE=\033[0;37m

# Text formatting
BOLD=\033[1m
UNDERLINE=\033[4m
RESET=\033[0m

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

GOLANGCI_LINT = $(LOCALBIN)/golangci-lint
GOSEC ?= $(LOCALBIN)/gosec

# Use the Go toolchain version declared in go.mod when building tools
GO_VERSION := $(shell awk '/^go /{print $$2}' go.mod)
GO_TOOLCHAIN := go$(GO_VERSION)
GOSEC_VERSION ?= latest
GOLANGCI_LINT_VERSION ?= latest

##@ Help
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build
.PHONY: build
build: build-ebpf ## Build the manager binary.
	go build ./...

.PHONY: build-ebpf
build-ebpf: ## Build eBPF programs for current architecture
	@echo "Detecting host architecture..."
	@HOST_ARCH=$$(uname -m); \
	case $$HOST_ARCH in \
		x86_64|amd64) TARGET_ARCH=x86 ;; \
		aarch64|arm64) TARGET_ARCH=arm64 ;; \
		armv7l|armv8l) TARGET_ARCH=arm ;; \
		riscv64) TARGET_ARCH=riscv ;; \
		*) echo "Unsupported architecture: $$HOST_ARCH"; exit 1 ;; \
	esac; \
	echo "Building eBPF for architecture: $$TARGET_ARCH (host: $$HOST_ARCH)"; \
	$(MAKE) -C eBPF TARGET_ARCH=$$TARGET_ARCH

.PHONY: build-all
build-all: build-ebpf build ## Build both eBPF and Go binaries

.PHONY: build-agent
build-agent: ## Build the agent binary
	go build -o bin/agent ./cmd/agent

##@ Multi-Architecture Build Support

# Architecture configuration
TARGET_ARCH ?= x86
DOCKER_PLATFORM ?= linux/amd64

# Architecture mappings
ARCH_MAP_amd64 = x86
ARCH_MAP_arm64 = arm64
ARCH_MAP_arm = arm
ARCH_MAP_riscv64 = riscv

.PHONY: build-ebpf-arch
build-ebpf-arch: ## Build eBPF for specific architecture (use TARGET_ARCH=<arch>)
	$(MAKE) -C eBPF TARGET_ARCH=$(TARGET_ARCH)

.PHONY: build-agent-arch
build-agent-arch: ## Build agent for specific architecture (use GOOS=<os> GOARCH=<arch>)
	CGO_ENABLED=0 GOOS=${GOOS:-linux} GOARCH=${GOARCH:-amd64} go build -o bin/agent-${GOARCH:-amd64} ./cmd/agent

.PHONY: build-cross
build-cross: ## Build for multiple architectures
	@echo "Building for multiple architectures..."
	@for arch in amd64 arm64 arm; do \
		echo "Building eBPF for $$arch..."; \
		$(MAKE) -C eBPF TARGET_ARCH=$$(echo "$(ARCH_MAP_$$arch)" | tr -d ' ') || exit 1; \
		mv eBPF/tcpconnect.bpf.o eBPF/tcpconnect.bpf.$$arch.o || exit 1; \
		echo "Building Go agent for $$arch..."; \
		CGO_ENABLED=0 GOOS=linux GOARCH=$$arch go build -o bin/agent-$$arch ./cmd/agent || exit 1; \
	done
	@echo "Cross-compilation complete!"

##@ Docker

.PHONY: docker-build
docker-build: ## Build Docker image for current platform
	docker build -t ebpf-tcp-monitor .

.PHONY: docker-build-arch
docker-build-arch: ## Build Docker image for specific platform (use DOCKER_PLATFORM=linux/<arch>)
	docker build --platform $(DOCKER_PLATFORM) -t ebpf-tcp-monitor:$(shell echo $(DOCKER_PLATFORM) | cut -d'/' -f2) .

.PHONY: docker-build-multi
docker-build-multi: ## Build Docker image for multiple platforms
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t ebpf-tcp-monitor:latest .

.PHONY: docker-push-multi
docker-push-multi: ## Build and push multi-platform Docker image
	docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7 -t $(REGISTRY)/ebpf-tcp-monitor:latest --push .

##@ Clean

.PHONY: clean
clean: clean-ebpf clean-bin ## Clean all build artifacts
	go clean ./...

.PHONY: clean-ebpf
clean-ebpf: ## Clean eBPF build artifacts
	$(MAKE) -C eBPF clean-all

.PHONY: clean-bin
clean-bin: ## Clean Go binaries
	rm -rf bin/

.PHONY: clean-docker
clean-docker: ## Clean Docker images
	docker rmi ebpf-tcp-monitor || true
	docker rmi $$(docker images ebpf-tcp-monitor -q) || true

##@ Development

.PHONY: dev-setup
dev-setup: $(LOCALBIN) ## Setup development environment
	@echo "Setting up development environment..."
	@mkdir -p bin/
	@echo "Installing development tools..."
	$(MAKE) golangci-lint
	$(MAKE) install-security-scanner
	@echo "Development environment ready!"

.PHONY: arch-info
arch-info: ## Show architecture build information
	@echo "Current system:"
	@echo "  GOOS: $$(go env GOOS)"
	@echo "  GOARCH: $$(go env GOARCH)"
	@echo ""
	@echo "Supported architectures:"
	@echo "  AMD64/x86_64: make TARGET_ARCH=x86 GOARCH=amd64"
	@echo "  ARM64:        make TARGET_ARCH=arm64 GOARCH=arm64"  
	@echo "  ARM32:        make TARGET_ARCH=arm GOARCH=arm"
	@echo "  RISC-V:       make TARGET_ARCH=riscv GOARCH=riscv64"
	@echo ""
	@echo "Docker platforms:"
	@echo "  linux/amd64, linux/arm64, linux/arm/v7, linux/riscv64"

##@ Code sanity

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: lint
lint: golangci-lint ## Run go vet against code.
	$(GOLANGCI_LINT) run --timeout 5m ./...

##@ Tests
.PHONY: test
test: ## Run unit tests.
	go test -v ./... -coverprofile coverage.out
	go tool cover -html=coverage.out -o coverage.html

.PHONY: bench
bench: ## Run benchmarks (override with BENCH=<regex>, PKG=<package pattern>, COUNT=<n>)
	@bench_regex=$${BENCH:-.}; \
	pkg_pattern=$${PKG:-./...}; \
	count=$${COUNT:-1}; \
	echo "Running benchmarks: regex=$${bench_regex} packages=$${pkg_pattern} count=$${count}"; \
	go test -run=^$$ -bench=$${bench_regex} -benchmem -count=$${count} $${pkg_pattern}

.PHONY: bench-profile
bench-profile: ## Run benchmarks with CPU & memory profiles (outputs bench.cpu, bench.mem)
	@bench_regex=$${BENCH:-.}; \
	pkg_pattern=$${PKG:-./pkg/loggers/vlog}; \
	echo "Profiling benchmarks: regex=$${bench_regex} packages=$${pkg_pattern}"; \
	go test -run=^$$ -bench=$${bench_regex} -cpuprofile bench.cpu -memprofile bench.mem -benchmem $${pkg_pattern}

deps: ## Download and verify dependencies
	@echo "Downloading dependencies..."
	@go mod download
	@go mod verify
	@go mod tidy
	@echo "Dependencies updated!"

update-deps: ## Update dependencies
	@echo "Updating dependencies..."
	@go get -u ./...
	@go mod tidy
	@echo "Dependencies updated!"

##@ Tools

.PHONY: golangci-lint
golangci-lint: $(LOCALBIN) ## Download golangci-lint locally if necessary.
	$(call go-install-tool,$(GOLANGCI_LINT),github.com/golangci/golangci-lint/cmd/golangci-lint,$(GOLANGCI_LINT_VERSION))

.PHONY: install-security-scanner
install-security-scanner: $(GOSEC) ## Install gosec security scanner locally (static analysis for security issues)
$(GOSEC): $(LOCALBIN)
	@set -e; echo "Attempting to install gosec $(GOSEC_VERSION)"; \
	if ! GOBIN=$(LOCALBIN) go install github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION) 2>/dev/null; then \
		echo "Primary install failed, attempting install from @main (compatibility fallback)"; \
		if ! GOBIN=$(LOCALBIN) go install github.com/securego/gosec/v2/cmd/gosec@main; then \
			echo "gosec installation failed for versions $(GOSEC_VERSION) and @main"; \
			exit 1; \
		fi; \
	fi; \
	echo "gosec installed at $(GOSEC)"; \
	chmod +x $(GOSEC)

##@ Security
.PHONY: go-security-scan
go-security-scan: install-security-scanner ## Run gosec security scan (fails on findings)
	$(GOSEC) ./...
# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f "$(1)-$(3)" ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
rm -f $(1) || true ;\
GOTOOLCHAIN=$(GO_TOOLCHAIN) GOBIN=$(LOCALBIN) go install $${package} ;\
mv $(1) $(1)-$(3) ;\
} ;\
ln -sf $(1)-$(3) $(1)
endef
# Default target architecture (can be overridden via command line)
TARGET_ARCH ?= x86

# Architecture-specific defines
ARCH_DEFINES = -D__TARGET_ARCH_$(TARGET_ARCH)

BPF_OBJ=tcpconnect.bpf.o
VMLINUX_H=vmlinux.h
LIBBPF_HEADERS=include/bpf/bpf_helpers.h

# Support for different architectures
# Usage examples:
#   make                          # builds for x86 (default)
#   make TARGET_ARCH=arm64        # builds for arm64
#   make TARGET_ARCH=aarch64      # builds for aarch64
#   make TARGET_ARCH=riscv        # builds for riscv

all: $(VMLINUX_H) $(LIBBPF_HEADERS) $(BPF_OBJ)

# Generate vmlinux.h if it doesn't exist
$(VMLINUX_H):
	@if command -v bpftool >/dev/null 2>&1; then \
		echo "Generating $(VMLINUX_H) from running kernel..."; \
		bpftool btf dump file /sys/kernel/btf/vmlinux format c > $(VMLINUX_H); \
	else \
		echo "Warning: bpftool not found. Using minimal vmlinux.h stub."; \
		echo "For production builds, generate vmlinux.h on a Linux system with:"; \
		echo "  bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h"; \
		echo ""; \
		echo "Creating minimal stub for development..."; \
		echo "/* Minimal vmlinux.h stub - replace with proper version */" > $(VMLINUX_H); \
		echo "#ifndef __VMLINUX_H__" >> $(VMLINUX_H); \
		echo "#define __VMLINUX_H__" >> $(VMLINUX_H); \
		echo "" >> $(VMLINUX_H); \
		echo "/* Basic types */" >> $(VMLINUX_H); \
		echo "typedef unsigned char __u8;" >> $(VMLINUX_H); \
		echo "typedef unsigned short __u16;" >> $(VMLINUX_H); \
		echo "typedef unsigned int __u32;" >> $(VMLINUX_H); \
		echo "typedef unsigned long long __u64;" >> $(VMLINUX_H); \
		echo "typedef signed char __s8;" >> $(VMLINUX_H); \
		echo "typedef signed short __s16;" >> $(VMLINUX_H); \
		echo "typedef signed int __s32;" >> $(VMLINUX_H); \
		echo "typedef signed long long __s64;" >> $(VMLINUX_H); \
		echo "typedef __u8 u8;" >> $(VMLINUX_H); \
		echo "typedef __u16 u16;" >> $(VMLINUX_H); \
		echo "typedef __u32 u32;" >> $(VMLINUX_H); \
		echo "typedef __u64 u64;" >> $(VMLINUX_H); \
		echo "typedef __s8 s8;" >> $(VMLINUX_H); \
		echo "typedef __s16 s16;" >> $(VMLINUX_H); \
		echo "typedef __s32 s32;" >> $(VMLINUX_H); \
		echo "typedef __s64 s64;" >> $(VMLINUX_H); \
		echo "" >> $(VMLINUX_H); \
		echo "/* Network byte order types */" >> $(VMLINUX_H); \
		echo "typedef __u16 __be16;" >> $(VMLINUX_H); \
		echo "typedef __u32 __be32;" >> $(VMLINUX_H); \
		echo "typedef __u64 __be64;" >> $(VMLINUX_H); \
		echo "typedef __u16 __le16;" >> $(VMLINUX_H); \
		echo "typedef __u32 __le32;" >> $(VMLINUX_H); \
		echo "typedef __u64 __le64;" >> $(VMLINUX_H); \
		echo "" >> $(VMLINUX_H); \
		echo "/* Checksum type */" >> $(VMLINUX_H); \
		echo "typedef __u32 __wsum;" >> $(VMLINUX_H); \
		echo "" >> $(VMLINUX_H); \
		echo "/* Minimal kernel structures */" >> $(VMLINUX_H); \
		echo "struct sock {};" >> $(VMLINUX_H); \
		echo "struct __sk_buff {};" >> $(VMLINUX_H); \
		echo "struct tcphdr {};" >> $(VMLINUX_H); \
		echo "" >> $(VMLINUX_H); \
		echo "#endif /* __VMLINUX_H__ */" >> $(VMLINUX_H); \
	fi

# Download libbpf headers if not present (for macOS development)
$(LIBBPF_HEADERS):
	@echo "Downloading libbpf headers for local development..."
	@mkdir -p include/bpf
	@curl -sSL https://raw.githubusercontent.com/libbpf/libbpf/v1.4.0/src/bpf_helpers.h -o include/bpf/bpf_helpers.h
	@curl -sSL https://raw.githubusercontent.com/libbpf/libbpf/v1.4.0/src/bpf_tracing.h -o include/bpf/bpf_tracing.h
	@curl -sSL https://raw.githubusercontent.com/libbpf/libbpf/v1.4.0/src/bpf_helper_defs.h -o include/bpf/bpf_helper_defs.h
	@curl -sSL https://raw.githubusercontent.com/libbpf/libbpf/v1.4.0/src/bpf_core_read.h -o include/bpf/bpf_core_read.h
	@echo "libbpf headers downloaded successfully"

$(BPF_OBJ): tcpconnect.bpf.c $(VMLINUX_H) $(LIBBPF_HEADERS)
	@echo "Attempting to compile eBPF program..."
	@if clang -O2 -g -target bpf $(ARCH_DEFINES) -c $< -o $@ -I. -I./include 2>/dev/null; then \
		echo "eBPF compilation successful!"; \
	else \
		echo ""; \
		echo "WARNING: eBPF compilation failed."; \
		echo "This is expected on macOS where clang doesn't have BPF target support."; \
		echo ""; \
		echo "To compile eBPF on Linux, you can:"; \
		echo "  1. Use Docker: docker run --rm -v \$$(pwd):/src -w /src/eBPF ubuntu:latest bash -c 'apt update && apt install -y clang llvm make libbpf-dev linux-headers-generic && make'"; \
		echo "  2. Use the CI/CD pipeline to build"; \
		echo "  3. Use a Linux VM or WSL"; \
		echo ""; \
		echo "Creating placeholder object file for local development..."; \
		touch $(BPF_OBJ); \
	fi

clean:
	rm -f $(BPF_OBJ)

clean-all:
	rm -f $(BPF_OBJ) $(VMLINUX_H)
	rm -rf include/

# Force regeneration of vmlinux.h
regen-vmlinux:
	rm -f $(VMLINUX_H)
	$(MAKE) $(VMLINUX_H)

# Show current configuration
info:
	@echo "Target Architecture: $(TARGET_ARCH)"
	@echo "Architecture Defines: $(ARCH_DEFINES)"
	@echo "Output Object: $(BPF_OBJ)"

# Help target
help:
	@echo "Available targets:"
	@echo "  all          - Build the BPF object (default)"
	@echo "  clean        - Remove built objects"
	@echo "  clean-all    - Remove built objects and vmlinux.h"
	@echo "  regen-vmlinux - Force regeneration of vmlinux.h"
	@echo "  info         - Show current build configuration"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Architecture options (use TARGET_ARCH=<arch>):"
	@echo "  x86          - Intel/AMD x86_64 (default)"
	@echo "  arm64        - ARM 64-bit"
	@echo "  aarch64      - ARM 64-bit (alias for arm64)"
	@echo "  arm          - ARM 32-bit"
	@echo "  riscv        - RISC-V"
	@echo ""
	@echo "Examples:"
	@echo "  make TARGET_ARCH=arm64"
	@echo "  make TARGET_ARCH=x86 clean all"
	@echo ""
	@echo "Note: On macOS, vmlinux.h will be auto-generated as a minimal stub."
	@echo "      For production, generate it on Linux with bpftool."

.PHONY: all clean clean-all regen-vmlinux info help

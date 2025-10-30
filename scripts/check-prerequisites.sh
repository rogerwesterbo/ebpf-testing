#!/bin/bash
# Prerequisites check for debugging

echo "🔍 Prerequisites Check for eBPF Debugging"
echo "=========================================="
echo ""

ALL_GOOD=true

# Check kubectl
echo -n "Checking kubectl... "
if kubectl cluster-info &>/dev/null; then
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs)
    echo "✅ Connected (${NODES} nodes)"
else
    echo "❌ Not connected to cluster"
    ALL_GOOD=false
fi

# Check Docker
echo -n "Checking Docker... "
if docker info &>/dev/null 2>&1; then
    echo "✅ Running"
else
    echo "❌ Not running"
    ALL_GOOD=false
fi

# Check VS Code Go extension
echo -n "Checking VS Code Go extension... "
if command -v code &>/dev/null; then
    if code --list-extensions 2>/dev/null | grep -q golang.go; then
        echo "✅ Installed"
    else
        echo "⚠️  Not found (install: code --install-extension golang.go)"
    fi
else
    echo "ℹ️  VS Code CLI not available"
fi

# Check for Delve locally (optional)
echo -n "Checking Delve (local)... "
if command -v dlv &>/dev/null; then
    VERSION=$(dlv version 2>/dev/null | head -1 | awk '{print $3}')
    echo "✅ Installed ($VERSION)"
else
    echo "ℹ️  Not installed (optional - runs in container)"
fi

# Check eBPF object file
echo -n "Checking eBPF object file... "
if [ -f "eBPF/tcpconnect.bpf.o" ]; then
    echo "✅ Built"
else
    echo "⚠️  Not found (will be built in container)"
fi

# Check if cluster has eBPF support (via Cilium)
echo -n "Checking cluster eBPF support... "
if kubectl get pods -n kube-system -l k8s-app=cilium &>/dev/null 2>&1; then
    CILIUM_PODS=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | wc -l | xargs)
    if [ "$CILIUM_PODS" -gt 0 ]; then
        echo "✅ Cilium running (${CILIUM_PODS} pods)"
    else
        echo "⚠️  Cilium not detected"
    fi
else
    echo "ℹ️  Cilium check skipped"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$ALL_GOOD" = true ]; then
    echo "✅ All required prerequisites met!"
    echo ""
    echo "📝 Next steps:"
    echo "   1. Run: ./scripts/debug-k8s.sh"
    echo "   2. Open VS Code"
    echo "   3. Press F5 and select 'Attach to Kubernetes Pod'"
    echo ""
    echo "📚 For help, see: docs/DEBUGGING.md"
else
    echo "❌ Some required prerequisites are missing"
    echo ""
    echo "📚 See docs/PREREQUISITES.md for setup instructions"
fi

echo ""

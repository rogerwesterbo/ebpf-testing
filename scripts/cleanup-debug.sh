#!/bin/bash
# Cleanup debug resources

set -e

NAMESPACE="ebpf-debug"

echo "🧹 Cleaning up debug resources..."
echo ""

if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "🗑️  Deleting debug deployment..."
    kubectl delete -f k8s/debug-deployment.yaml
    echo "✅ Debug resources deleted"
else
    echo "ℹ️  No debug resources found"
fi

echo ""
echo "✅ Cleanup complete"

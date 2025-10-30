#!/bin/bash
# Quick debug setup script for Kubernetes

set -e

NAMESPACE="ebpf-debug"
APP_NAME="ebpf-testing-debug"

echo "🔍 eBPF Testing - Kubernetes Debug Setup"
echo "========================================"
echo ""

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ docker is required but not installed."; exit 1; }

echo "✅ Prerequisites check passed"
echo ""

# Build debug image
echo "🏗️  Building debug Docker image..."
docker build -f Dockerfile.debug -t ebpf-testing:debug .
echo "✅ Debug image built"
echo ""

# Deploy to Kubernetes
echo "🚀 Deploying to Kubernetes..."
kubectl apply -f k8s/debug-deployment.yaml
echo "✅ Deployment created"
echo ""

# Wait for pod to be ready
echo "⏳ Waiting for pod to be ready..."
kubectl wait --for=condition=ready pod -l app=$APP_NAME -n $NAMESPACE --timeout=60s
echo "✅ Pod is ready"
echo ""

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=$APP_NAME -o jsonpath='{.items[0].metadata.name}')
echo "📦 Pod name: $POD_NAME"
echo ""

# Setup port forwarding
echo "🔌 Setting up port forwarding..."
echo "   Delve:   localhost:2345"
echo "   Metrics: localhost:9090"
echo "   Health:  localhost:8080"
echo ""
echo "Press Ctrl+C to stop port forwarding when done debugging"
echo ""

kubectl port-forward -n $NAMESPACE $POD_NAME 2345:2345 9090:9090 8080:8080

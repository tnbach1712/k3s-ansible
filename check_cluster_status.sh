#!/bin/bash

echo "=========================================="
echo "K3S Cluster Status Check"
echo "=========================================="
echo ""

# Check cluster info
echo "=== CLUSTER INFO ==="
kubectl cluster-info 2>/dev/null || echo "ERROR: Cannot connect to cluster"
echo ""

# Check nodes
echo "=== NODES STATUS ==="
kubectl get nodes -o wide
echo ""

# Check component status
echo "=== COMPONENT STATUS ==="
kubectl get componentstatuses 2>/dev/null || echo "Note: Component statuses may not be available in k3s"
echo ""

# Check system pods
echo "=== SYSTEM PODS ==="
kubectl get pods -n kube-system
echo ""

# Check kube-vip
echo "=== KUBE-VIP STATUS ==="
kubectl get pods -n kube-system -l app=kube-vip
echo ""

# Check MetalLB
echo "=== METALLB STATUS ==="
kubectl get pods -n metallb-system
echo ""

# Check virtual IP
echo "=== VIRTUAL IP CHECK ==="
echo "API Server Endpoint should be: 192.168.0.50"
kubectl cluster-info | grep "Kubernetes master"
echo ""

# Check kubeconfig
echo "=== KUBECONFIG STATUS ==="
echo "Default kubeconfig location: ~/.kube/config"
test -f ~/.kube/config && echo "✓ Local kubeconfig found" || echo "✗ Local kubeconfig NOT found"
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
READY_NODES=$(kubectl get nodes --no-headers | wc -l)
echo "Ready nodes: $READY_NODES"
TOTAL_PODS=$(kubectl get pods -A --no-headers | wc -l)
echo "Total pods: $TOTAL_PODS"

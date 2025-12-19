#!/bin/bash
set -e

echo "=== Docker Registry Deployment Script ==="
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

echo
echo "Step 3: Applying Kubernetes manifests"
kubectl apply -f "../namespace.yaml"
kubectl apply -f "../pvc.yaml"
kubectl apply -f "../config.yaml"
kubectl apply -f "../auth-secret.yaml"
kubectl apply -f "../deployment.yaml"
kubectl apply -f "../service.yaml"
kubectl apply -f "../ingress.yaml"

echo
echo "Step 4: Waiting for registry pod to be ready..."
kubectl wait --for=condition=ready pod -l app=registry -n registry --timeout=300s

echo
echo "=== Registry Deployment Complete ==="
echo
echo "Registry URL: https://reg.crimelabs.dev"
echo "Username: $REGISTRY_USER"
echo
echo "To test the registry:"
echo "  docker login reg.crimelabs.dev"
echo "  docker tag myimage:latest reg.crimelabs.dev/myimage:latest"
echo "  docker push reg.crimelabs.dev/myimage:latest"
echo
echo "To create image pull secret for other namespaces:"
echo "  kubectl create secret docker-registry regcred \\"
echo "    --docker-server=reg.crimelabs.dev \\"
echo "    --docker-username=$REGISTRY_USER \\"
echo "    --docker-password=<password> \\"
echo "    -n <namespace>"
echo

# Clean up
rm -rf "$TEMP_DIR"
echo "Temporary files cleaned up."

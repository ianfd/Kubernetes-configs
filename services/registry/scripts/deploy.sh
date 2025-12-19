#!/bin/bash
set -e

echo "=== Docker Registry Deployment Script ==="
echo

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found. Please install kubectl first."
    exit 1
fi

# Generate htpasswd credentials
echo "Step 1: Generate registry credentials"
echo "Enter registry username:"
read -r REGISTRY_USER
echo "Enter registry password:"
read -rs REGISTRY_PASS
echo

# Generate htpasswd using docker
echo "Generating htpasswd..."
HTPASSWD=$(docker run --rm httpd:2 htpasswd -Bbn "$REGISTRY_USER" "$REGISTRY_PASS")

# Generate random secret for registry
echo "Step 2: Generate registry HTTP secret"
REGISTRY_SECRET=$(openssl rand -hex 32)

# Create temporary directory for manifests
TEMP_DIR=$(mktemp -d)
echo "Using temporary directory: $TEMP_DIR"

# Copy all YAML files to temp directory
cp ../*.yaml "$TEMP_DIR/"

# Update the auth secret with generated htpasswd
cat > "$TEMP_DIR/registry-auth-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: registry-auth
  namespace: registry
type: Opaque
stringData:
  htpasswd: |
$(echo "$HTPASSWD" | sed 's/^/    /')
EOF

echo
echo "Step 3: Applying Kubernetes manifests"
kubectl apply -f "$TEMP_DIR/namespace.yaml"
kubectl apply -f "$TEMP_DIR/pvc.yaml"
kubectl apply -f "$TEMP_DIR/config.yaml"
kubectl apply -f "$TEMP_DIR/auth-secret.yaml"
kubectl apply -f "$TEMP_DIR/deployment.yaml"
kubectl apply -f "$TEMP_DIR/service.yaml"
kubectl apply -f "$TEMP_DIR/ingress.yaml"

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
